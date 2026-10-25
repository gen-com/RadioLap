# 레이스 목록 Repository 계약

[기능 목적](../README.md)과 [현재 작업 범위](../AGENTS.md#현재-작업-범위)를 바탕으로, 목록 정제 전 후보 데이터를 제공하는 계약입니다. 선별·정제·최신순 정렬은 [UseCase 계약](UseCaseContract.md)을 따릅니다.

## 책임과 입출력

Repository는 데이터를 요청하고, 외부 응답을 해석·연결하여 도메인 모델로 변환합니다. 목록 포함 여부를 결정하거나 중복을 제거하지 않으며, 반환 순서를 보장하지 않습니다.

```swift
protocol RaceListRepository: Sendable {
    func fetchRaceCandidates(year: Int) async throws -> [RaceCandidate]
}
```

| 항목 | 의미 |
| --- | --- |
| `year` | 요청할 시즌. 데이터 요청 범위를 지정하며 기기 시간대에 영향을 받지 않습니다. 반환할 결승의 시즌 확인은 UseCase가 수행합니다. |
| `[RaceCandidate]` | 외부 응답 형식과 독립적인 정제 전 도메인 모델 목록. 정보 누락과 중복을 보존합니다. |
| 빈 배열 | 조회는 성공했으나 제공할 후보 데이터가 없는 경우입니다. |

`endedBefore`는 Repository 입력에 포함하지 않습니다. 현재 시각을 별도로 읽거나 종료 여부를 판단하지 않습니다.

## 데이터 요청과 연결

OpenF1 Provider는 요청한 시즌의 대회와 세션 자료를 조회하고 `meeting_key`로 연결합니다. 두 요청은 독립적이며 레이스마다 추가 요청하지 않습니다. 2026 시즌의 요청 예시는 다음과 같습니다.

```http
GET https://api.openf1.org/v1/meetings?year=2026
GET https://api.openf1.org/v1/sessions?year=2026&session_name=Race
```

결승 조건을 외부 요청에 전달하더라도 최종 반환할 레이스의 선별은 UseCase가 보장합니다. Repository는 받은 후보를 종료 여부·정보 유효성·중복 정책으로 제거하지 않습니다. API 정보는 [OpenF1 문서](https://openf1.org/docs/)를 참고합니다.

- 대회와 세션은 식별자로 연결하며 응답 순서나 대회 이름으로 연결하지 않습니다.
- 대회 정보가 연결되지 않아도 해당 세션 후보를 보존하고 연결 누락을 표현합니다.
- 연결되는 대회 정보가 중복·충돌하면 임의의 하나를 선택하거나 충돌 정보를 없애지 않습니다. 연결된 모든 대회 정보를 `linkedMeetings`에 보존합니다.
- 드라이버 결과와 라디오 데이터는 요청하지 않습니다.

## 후보 모델의 의미

`RaceCandidate`는 Repository가 제공하고 UseCase가 선별·정제하는 도메인 모델입니다. 다음 속성과 타입을 사용합니다. 모델 선언과 실제 변환 동작의 검증은 구분합니다.

```swift
struct RaceCandidate: Equatable, Sendable {
    let sessionID: Int?
    let season: Int?
    let kind: RaceSessionKind?
    let isCancelled: Bool?
    let startsAt: Date?
    let endsAt: Date?
    let location: String?
    let linkedMeetings: [RaceMeetingCandidate]
}

struct RaceMeetingCandidate: Equatable, Sendable {
    let name: String?
    let season: Int?
    let isCancelled: Bool?
}

enum RaceSessionKind: Equatable, Sendable {
    case race
    case other
}
```

| 속성 | 의미와 변환 기준 |
| --- | --- |
| `sessionID` | 세션의 `session_key`. 식별할 수 없으면 nil로 표현합니다. 결승 식별과 중복 판단에 사용합니다. |
| `season` | 세션의 시즌. 확인할 수 없으면 nil로 표현합니다. 요청 시즌과의 일치는 UseCase가 판단합니다. |
| `kind` | 결승이면 race, 연습·예선·스프린트처럼 결승이 아님을 확인하면 other입니다. 누락되거나 판별할 수 없으면 nil이며, 알 수 없는 값을 other로 간주하지 않습니다. |
| `isCancelled` | 세션 취소 여부. 확인할 수 없으면 nil로 표현하며 임의로 false로 채우지 않습니다. |
| `startsAt`, `endsAt` | 세션의 시작·종료 절대 시각. 대회 주말 시작일과 구분하며, 누락·해석 불가는 nil입니다. |
| `location` | 세션의 장소. 누락·null·빈 문자열은 nil로 정규화합니다. |
| `linkedMeetings` | 해당 세션에 연결된 모든 대회 정보. 전체 대회 목록이 아니며, 연결이 없으면 빈 배열입니다. |

`RaceMeetingCandidate.name`은 연결된 대회의 이름이며 누락·해석 불가는 nil입니다. 빈 문자열과 공백뿐인 이름은 그대로 보존합니다. `season`과 `isCancelled`는 대회의 시즌과 취소 여부이며, 확인할 수 없으면 nil로 표현합니다.

### 정보 보존과 정제의 경계

- `linkedMeetings`가 비어 있으면 연결 누락, 한 항목이면 연결된 대회 정보, 여러 항목이면 동일 중복 또는 충돌 가능한 대회 정보입니다. Repository는 임의로 하나를 선택하거나 중복을 제거하지 않습니다.
- 대회 연결은 Repository가 `meeting_key`로 완료합니다. UseCase가 다시 외부 식별자로 연결하지 않으므로 후보 모델에는 `meeting_key`를 포함하지 않습니다.
- 이름·시각의 누락·해석 불가, 빈 이름·공백 이름을 이유로 후보를 버리거나 조회 전체를 실패시키지 않습니다.
- 해석 가능한 날짜는 절대 시각으로 변환합니다. 시차 표기가 달라도 같은 순간이면 같은 값이며, 기기 시간대가 바뀌어도 값은 유지됩니다.
- 종료 시각이 시작 시각보다 이르거나 같아도 두 값을 그대로 전달합니다. 해당 후보의 제외는 UseCase가 판단합니다.
- 후보 목록과 `linkedMeetings`의 중복·충돌을 보존하며, 선별·중복 제거·정렬은 수행하지 않습니다.
- Optional은 불확실한 값을 표현하기 위한 타입입니다. nil을 기본값으로 채우지 않으며, 해당 후보의 제외 여부는 [UseCase 계약](UseCaseContract.md#필수-정보와-대회-연결)에서 정의합니다.
- JSON 자체를 읽을 수 없는 전체 실패는 불완전한 후보로 변환하지 않고 오류로 전달합니다. 후보 모델에 JSON 구조·외부 필드명·화면 표시 문자열을 노출하지 않습니다.

## 전체 실패와 취소

| 상황 | Repository 동작 |
| --- | --- |
| HTTP 오류·통신 실패 | 오류 전달 |
| JSON 문법 오류 등 응답 전체를 읽거나 해석할 수 없음 | 오류 전달 |
| 파일·번들 리소스 누락 또는 파일 읽기 실패 | 오류 전달 |
| 작업 취소 | `CancellationError`로 전달 |

조회 전체의 실패를 빈 배열로 바꾸지 않습니다. 이름·시각의 개별 문제와 응답 전체 해석 실패를 구분합니다. 구체적인 일반 오류 타입은 구현 계획에서 정하며, 사용자 안내는 Presentation이 담당합니다.

## 관련 계약과 검증 경계

식별 불가·필수 정보 부족·시즌 불일치·중복 충돌의 처리와 정렬은 [UseCase 계약](UseCaseContract.md)을 따릅니다. Repository는 판단에 필요한 정보를 보존하며 이 정책을 직접 수행하지 않습니다. 책임별 검증 경계는 [완료기준](CompletionCriteria.md#검증-경계)을 참고합니다.
