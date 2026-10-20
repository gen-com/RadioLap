# 레이스 목록 Repository 계약
[기능 문맥](Context.md)을 바탕으로 한 데이터 접근 계약입니다. Domain 모델·프로토콜·데모 Provider를 구현했습니다. 실제 API Provider와 목록 화면은 구현 전입니다.

## 데이터 조회
OpenF1 Provider는 다음 두 목록을 조회하고 `meeting_key`로 연결합니다. 두 요청은 독립적이므로 병렬 조회할 수 있으며, 레이스마다 별도 요청하지 않습니다.

```http
GET https://api.openf1.org/v1/meetings?year=2026
GET https://api.openf1.org/v1/sessions?year=2026&session_name=Race
```

두 응답은 JSON 배열입니다. 대회 이름은 meeting에서, 결승 식별자·시각·장소는 session에서 가져옵니다.
API 정보는 [OpenF1 문서](https://openf1.org/docs/)를 참고합니다.

Provider가 응답 연결·조건 적용·Domain 모델 변환을 담당합니다. ViewModel은 Repository를 한 번 호출하고, 결과를 최신순으로 정렬해 화면 상태로 표현합니다.

## 계약과 모델
구현된 [Race](../Domain/Race.swift)와 [RaceListRepository](../Domain/RaceListRepository.swift)의 계약입니다. 각 속성과 메서드의 인자·반환값·오류 조건은 소스의 문서 주석에서도 확인할 수 있습니다.
```swift
nonisolated protocol RaceListRepository: Sendable {
    func fetchRaces(
        year: Int,
        endedBefore: Date
    ) async throws -> [Race]
}

struct Race: Identifiable, Equatable, Sendable {
    let sessionID: Int
    let name: String
    let startsAt: Date
    let location: String?

    var id: Int { sessionID }
}
```

| 입력 | 의미 |
| --- | --- |
| `year` | 조회할 시즌. 화면에 표시된 날짜와 무관하며, 첫 화면은 `2026`을 전달합니다. |
| `endedBefore` | 종료 여부의 기준 시각. 아래 시간 기준을 따릅니다. |

반환하는 각 레이스는 다음 조건을 만족해야 합니다.
- 요청한 시즌의 결승(`session_name == Race`)입니다. 연습·예선·스프린트는 제외합니다.
- 대회와 세션 모두 취소되지 않았습니다.
- 아래 시간 기준에 따라 종료된 결승입니다.
- 반환 목록에 같은 `sessionID`가 중복되지 않습니다.

반환 순서는 보장하지 않으며, 최신순 정렬은 ViewModel이 담당합니다.
| 반환 필드 | 의미 / API 매핑 |
| --- | --- |
| `sessionID` | 목록 식별과 상세 조회에 사용하는 session의 `session_key` |
| `name` | meeting의 `meeting_name` |
| `startsAt` | session의 `date_start`를 `Date`로 변환한 결승 시작 시각 |
| `location` | session의 `location`. 누락되거나 빈 문자열이면 `nil` |

- `meeting_key`는 Provider 내부의 연결 키로 사용합니다.
- 날짜 표시 문자열, 로딩 상태, 오류 메시지는 `Race`에 포함하지 않습니다.

### 시간 기준
- **시작 시각**: `startsAt`은 대회 주말이 아닌 결승 세션의 시작 시각입니다. 시간대와 무관한 `Date`로 반환하며, 목록의 날짜 표시와 최신순 정렬에 사용합니다.
- **종료 판단**: API의 세션 종료 시각이 `endedBefore`보다 이른 결승만 반환합니다. 호출자가 조회 시작 시점의 현재 시각을 전달하며, Provider는 이를 기준으로 판단합니다. 종료 시각이 기준과 같으면 제외합니다. 결과 확정이나 라디오 데이터 준비 완료를 보장하지 않습니다.
- **화면 표시**: 날짜와 시간은 Presentation에서 사용자 기기의 시간대로 표시합니다. 시간대는 조회 조건과 정렬에 영향을 주지 않습니다. 세부 표시 규칙은 [화면 상태](PresentationState.md#화면-표시와-이동)를 따릅니다.

### 빈 결과·실패·취소
| 상황 | Repository 동작 |
| --- | --- |
| 정상 조회했으나 조건에 맞는 결승 없음 | 빈 배열 반환 |
| 장소 누락 또는 빈 문자열 | `location = nil`로 반환 |
| 통신 실패 | 오류 전달 |
| 필수 데이터 해석 실패 또는 필요한 대회 정보 연결 실패 | 데이터 오류 전달 |
| 작업 취소 | `CancellationError`로 전달 |
- 실패를 빈 배열로 바꾸거나, 필수 데이터가 잘못된 대상 항목을 조용히 버리지 않습니다.
- 구체적인 오류 타입과 HTTP 오류의 사용자 안내 문구 매핑은 구현 계획에서 정합니다.

관련 검증 기준은 [완료기준의 Repository와 Provider 항목](CompletionCriteria.md#repository와-provider)을 따릅니다.

## 데모 구현
[DemoRaceListProvider](../Data/DemoRaceListProvider.swift)는 번들 또는 직접 전달한 파일 URL에서 meetings.json·sessions.json을 읽습니다.
네트워크에 접근하지 않으며, 실제 API Provider와 같은 조회 조건과 반환 계약을 따릅니다.

[RaceListResponseMapper](../Data/RaceListResponseMapper.swift)는 파일·네트워크와 독립적으로 JSON 해석, 대회·세션 연결, 조건 적용과 검증, Race 변환을 담당합니다.
- 제외 대상도 필수 필드·타입·날짜를 해석할 수 있어야 하며, 디코딩 오류는 전체 조회 실패로 전달합니다.
- 표시 대상에 필요한 연결과 값의 유효성을 검증합니다. 동일한 중복은 합치고, 표시 여부나 표시 대상의 내용이 충돌하면 오류를 전달합니다.
- 파일 누락·읽기 실패와 데이터 처리 오류를 빈 결과로 바꾸지 않습니다.
- 각 파일 읽기와 각 응답 디코딩이 완료된 뒤, 변환 반복 중과 최종 반환 직전에 취소를 확인합니다. 동기 읽기·디코딩 자체를 중단하지는 않습니다.
세부 처리와 검증 기준은 위 코드와 [완료기준](CompletionCriteria.md#repository와-provider)을 참고합니다.

데모에 사용하는 저장 응답은 자동 갱신되지 않는 2026 시즌 자료입니다. 조회 기준 시각이 지나면 저장된 미래 일정도 종료 조건에 포함될 수 있으므로, 실제 최신 경기 상황을 보장하지 않습니다.
