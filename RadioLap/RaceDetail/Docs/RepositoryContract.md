# 레이스 상세 Repository 계약

[기능 목적](../README.md)에 필요한 참가자·결과 자료를 조회·해석·연결하여 정제 전 후보로 제공합니다. 참가자 정규화·중복 처리와 최종 상세 구성은 [UseCase 계약](UseCaseContract.md), 화면 동작은 [화면 상태 계약](PresentationState.md)을 따릅니다.

## 책임과 입출력

```swift
protocol RaceDetailRepository: Sendable {
    func fetchRaceDetailCandidate(sessionID: Int) async throws -> RaceDetailCandidate
}
```

입력은 목록에서 선택한 Race의 sessionID이며 별도의 숫자 범위 제한을 두지 않습니다. Race의 기본 정보는 UseCase가 보존하며 Repository에는 전달하지 않습니다. 세션·대회를 재조회하거나 결승·취소·종료 여부를 재판정하지 않습니다.

반환값은 외부 응답 형식과 독립적인 Domain 후보입니다. 필수 필드의 해석과 참가자·결과 연결은 완료하지만 문자열 정규화·중복 제거·표시 정렬은 하지 않습니다. 이 계약은 목표 설계이며 현재 코드와 테스트의 반영·검증 완료를 뜻하지 않습니다.

## RaceDetailCandidate의 구성

| 속성 | 내용 |
| --- | --- |
| drivers | 참가자 후보 목록. driverNumber: Int, name: String, acronym: String?, teamName: String?, results: [RaceResult] |
| unmatchedResults | 참가자에 연결되지 않은 결과 목록. driverNumber: Int, result: RaceResult |

자식 타입은 RaceDetailCandidate 내부의 Driver·UnmatchedResult입니다. RaceResult는 position: Int?와 didNotFinish·didNotStart·isDisqualified: Bool을 가지며 최종 모델과 공유합니다. 후보 모델은 Equatable·Sendable이며 저장 속성은 let입니다. 세션·대회 후보와 Race 기본 정보는 포함하지 않습니다.

- results가 비면 결과 레코드 미제공입니다. 결과가 있고 position만 nil이면 순위 없음입니다.
- 참가자·결과가 모두 비면 drivers·unmatchedResults가 빈 후보를 반환합니다. 조회 실패와 구분합니다.
- 동일·상충 중복을 모두 보존합니다. 같은 번호의 참가자 레코드가 여러 개면 각 레코드에 해당 번호의 모든 결과를 연결합니다.
- 배열 순서는 보장하지 않으며 드라이버를 임의로 제거하지 않습니다.
- 응답의 session_key는 Data에서 요청 범위를 검증하는 데 사용하며 후보에 중복 저장하지 않습니다.

## 요청과 연결

요청한 sessionID로 drivers와 session_result 자료를 조회하고 session_key + driver_number로 연결합니다. 이름·배열 순서·순위로 연결하지 않습니다. 두 자료 중 하나라도 조회·해석에 실패하면 전체 오류를 전달합니다. 드라이버별 추가 요청이나 세션·대회·라디오·랩·스틴트 조회는 하지 않습니다. 실제 API Provider 구현은 현재 범위에 포함하지 않습니다.

- 요청과 다른 session_key가 있으면 전체 오류입니다. 정상 자료와 섞여 있어도 조용히 제외하지 않습니다.
- 참가자가 없는 결과는 unmatchedResults로 보존합니다. 참가자를 생성하거나 결과를 버리지 않습니다.
- Race는 meeting_key를 전달하지 않습니다. 상세는 meeting_key를 연결·검증에 사용하지 않고 미사용 필드로 취급합니다.
- 여러 응답의 원자적 스냅샷은 보장하지 않습니다. 해당 조회에서 얻은 자료를 연결합니다.

## 합의한 사용 필드 매핑과 입력 검증

공식 필드 의미와 앱의 수용 조건은 구분합니다. 아래 필수성·타입·누락·null 처리는 RadioLap의 확정 정책이며, 모든 API 응답의 스키마 보장을 뜻하지 않습니다. Fixtures의 표본 값이 허용 규칙을 대신하지 않습니다.

| 원본 필드 | 반환 또는 검증 용도 |
| --- | --- |
| drivers.session_key · session_result.session_key | 요청 sessionID 일치 확인 |
| drivers.driver_number · session_result.driver_number | 참가자 후보의 driverNumber와 결과 연결 |
| drivers.full_name | 참가자 후보의 name. 다른 이름 필드로 대체하지 않음 |
| drivers.name_acronym | 참가자 후보의 acronym |
| drivers.team_name | 참가자 후보의 teamName |
| session_result.position | 결과의 position |
| session_result.dnf · session_result.dns · session_result.dsq | didNotFinish · didNotStart · isDisqualified |

| 입력 필드 | 허용 조건 |
| --- | --- |
| session_key | 필수 정수. 요청 sessionID와 일치해야 함 |
| driver_number | 필수 정수. 제공된 번호를 그대로 보존 |
| full_name | 필수 문자열. 공백과 빈 문자열을 포함해 그대로 보존 |
| name_acronym · team_name | 선택 문자열. 누락·null은 nil, 빈 값·공백은 그대로 보존 |
| position | 선택 정수. 누락·null은 nil, 제공된 정수는 그대로 보존 |
| dnf · dns · dsq | 각각 필수 Boolean. 누락·null·다른 타입은 오류 |

정수 값은 Swift Int로 표현 가능해야 하며 다른 타입이나 비정수 값을 변환하지 않습니다. 별도의 숫자 범위 제한 없이 제공된 값을 보존합니다.

## 응답 검증 범위

JSON 문법 오류, 배열이 아닌 최상위 응답, 객체가 아닌 원소, 사용하는 필드의 타입·필수성 오류와 Int 표현 범위 초과는 전체 실패입니다. 미사용 필드와 알 수 없는 필드는 무시합니다.

meeting_key, 드라이버의 대체 이름·사진·팀 색상, 결과의 duration·gap_to_leader·number_of_laps·points는 사용하지 않습니다. 날짜는 상세 Repository의 조회·해석 대상이 아닙니다.

## 데모 자료 공급 경계

요청 sessionID에 해당하는 상세의 drivers·session_result 파일을 읽습니다. 목록의 sessions·meetings 파일을 다시 읽거나 시즌 저장 자료를 선별하지 않습니다. 파일·번들 구성은 Data 내부에 둡니다.

파일 누락·읽기 실패도 조회 실패로 전달합니다.

## 실패와 취소

통신·HTTP·파일 읽기·응답 해석·연결 정합성 오류를 전달합니다. 구체 일반 오류 타입은 Data 구현 사항이며 공개 계약으로 강제하지 않습니다. 사용자 안내 문자열은 만들지 않습니다. 취소는 CancellationError로 통일합니다.

### 취소 확인 지점
| 시점 | 동작 |
| --- | --- |
| Repository 진입 직후 | 자료 조회 전에 확인 |
| 각 파일 읽기·네트워크 요청 직전과 완료 직후 | 취소를 관찰하면 후속 처리를 중단 |
| 각 응답 디코딩 직전과 완료 직후 | 취소를 확인한 뒤 다음 단계 진행 |
| 디코딩 후 레코드 검증·연결·변환의 각 반복 시작 | 취소를 확인하고 관찰 시 중단 |
| 최종 결과 반환 직전 | 정상 빈 결과를 포함해 취소 확인 |
| 일반 오류를 외부로 전달하기 직전 | Repository 작업의 취소 여부를 확인하여 전달 오류 결정 |

파일 읽기·디코딩 같은 동기 작업 도중 취소되면 작업이 끝난 다음 확인 지점에서 관찰할 수 있습니다. 동기 작업이 오류로 끝나면 일반 오류 전달 전 확인 정책을 적용합니다.

### 오류·취소 경합
| 상황 | 반환 정책 |
| --- | --- |
| 이미 취소된 작업으로 호출 | 자료 조회 전에 CancellationError 전달 |
| 일반 오류 발생 후 오류 전달 직전 취소 관찰 | CancellationError를 우선 전달 |
| 일반 오류 발생 후 마지막 확인에서도 취소되지 않음 | 원래 오류 전달 |
| 전송 계층의 취소 오류 수신 | CancellationError로 통일. 아래 하위 요청 정리 규칙 적용 |
| 성공 또는 오류가 이미 반환된 뒤 취소 | 반환 결과를 소급 변경하지 않음 |

취소가 발생한 실제 시각만으로 항상 우선권을 부여하지 않습니다. 오류 전달 전 확인 지점에서 관찰한 취소를 우선하며, 마지막 확인 이후 반환까지 발생한 취소를 놓칠 수 있습니다. 화면은 별도로 요청 유효성을 검사합니다.

### 병렬 요청의 실패와 정리
- 호출자가 Repository 작업을 취소한 경우 위 확인 정책에 따라 CancellationError를 전달합니다.
- 일반 실패 때문에 다른 하위 요청을 취소하여 정리하는 경우, 그 정리 과정의 취소가 원래 실패를 덮지 않도록 합니다. 하위 요청의 취소 상태를 Repository 작업 자체의 취소로 간주하지 않습니다.
- 정리 중 호출자 취소도 발생했다면 오류 전달 직전 Repository 작업의 취소 확인을 적용합니다.
- 일반 오류가 여러 개 발생하면 먼저 관찰한 오류 하나를 전달합니다. 병렬 실행에서 항상 같은 오류 종류가 선택되는 것은 보장하지 않습니다.
- 이 규칙은 병렬 요청을 구현할 경우의 계약이며, 병렬화를 의무화하거나 취소를 무시하는 하위 작업의 즉시 종료를 보장하지 않습니다.

## 검증 경계

Repository 검증은 참가자·결과 요청, 후보 반환, 중복·결과 부재·미연결 결과 보존과 실패·취소를 확인합니다. 참가자 정규화·중복 통합·결과 정합성과 전달받은 Race 보존은 UseCase 검증에서 다룹니다. 일반 오류는 구체 타입이나 여러 실패 사이의 고정 우선순위를 보장하지 않습니다. 늦은 응답의 화면 반영 차단은 Presentation 책임입니다.

## 공식 자료에서 확인한 내용

[OpenF1 공식 문서](https://openf1.org/docs/)와 결과 수집 코드에서 확인한 근거입니다.

- [Drivers](https://openf1.org/docs/#drivers)는 세션 참가자의 이름·약칭·팀 정보를 제공합니다.
- [Session result](https://openf1.org/docs/#session-result)의 position은 세션 종료 시 최종 순위이며, dnf·dns·dsq는 각각 미완주·미출발·실격을 나타내는 별도 필드입니다. 결과는 공식 발표 후 제공되므로 목록의 종료 판단이 결과 준비 완료를 보장하지 않습니다.
- [결과 수집 코드](https://github.com/br-g/openf1/blob/main/src/openf1/services/f1_scraping/session_result.py)는 DQ·NC·빈 순위 셀을 None으로 변환하고 각 상태를 Boolean으로 생성합니다. 이는 해당 수집 경로의 처리이며 모든 응답의 제약을 보장하지 않습니다.

필드의 필수성·누락·null 처리와 상태 조합은 예제나 수집 코드만으로 확정하지 않습니다. 순위 누락·null 수용, 상태 필드 누락 거부, 각 상태의 독립적 보존은 앞서 정한 앱 정책입니다. 상태 사이의 우선순위나 상태에 따른 순위 제거 규칙을 추론하지 않습니다.
