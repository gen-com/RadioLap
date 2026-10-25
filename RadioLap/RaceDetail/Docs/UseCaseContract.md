# 레이스 상세 UseCase 계약

[기능 목적](../README.md)을 바탕으로, [Repository](RepositoryContract.md)가 반환한 참가자·결과 후보를 검증·정리하고 목록에서 받은 Race와 함께 상세를 제공합니다. 외부 응답을 직접 해석하거나 화면 상태·그룹을 만들지 않습니다.

## 책임과 입출력

```swift
protocol RaceDetailUseCase: Sendable {
    func fetchRaceDetail(race: Race) async throws -> RaceDetail
}
```

입력은 목록에서 선택한 Race입니다. Race의 구성과 선별 보장은 [목록 UseCase 계약](../../RaceList/Docs/UseCaseContract.md)을 따릅니다. 취소를 먼저 확인한 뒤 Repository에 race.sessionID만 전달하며, 식별자의 숫자 범위를 별도로 검사하지 않습니다. 구현은 Repository 계약에 의존하며 ViewModel은 UseCase 계약을 사용합니다. 구체 구현은 Domain의 RaceDetailInteractor이며 init(repository: any RaceDetailRepository)로 Repository를 주입받습니다.

반환 모델은 다음 의미를 가집니다. 선언은 목표 계약이며 기존 코드의 반영·검증 상태와 구분합니다.

| 모델 | 필드와 의미 |
| --- | --- |
| RaceDetail | race: Race, drivers: [RaceDriver]. 입력 Race를 그대로 보존하며 기본 정보를 속성별로 복제하지 않음 |
| RaceDriver | driverNumber: Int, name: String, acronym: String?, teamName: String?, result: RaceResult? |
| RaceResult | position: Int?, didNotFinish: Bool, didNotStart: Bool, isDisqualified: Bool |

세 모델은 Equatable·Sendable이며 저장 속성은 let입니다. RaceDriver는 Identifiable이며 id는 driverNumber입니다. 이는 해당 상세 안에서만 유일하고, 다른 화면 이동에는 sessionID와 함께 사용합니다. 영구 드라이버 프로필이 아니며 번호·팀은 해당 세션의 값입니다.

Race.season은 목록이 검증한 세션의 시즌이고 Race.startsAt은 절대 시각입니다. 날짜에서 시즌을 계산하지 않습니다. 외부 DTO·연결 키·인원수·그룹·표시 문자열·화면 상태는 최종 모델에 포함하지 않습니다.

## 기본 정보 보존과 결과 정합성

- Race의 sessionID·season·name·startsAt·location을 그대로 보존합니다. 이름·장소를 다시 정규화하거나 상세 조회 값으로 덮어쓰지 않습니다.
- 세션·대회 조회와 결승·취소·시즌 일치·종료 여부 판정은 목록의 책임입니다. 상세에서 반복하지 않습니다.
- 참가자·결과의 요청 범위와 식별자 연결은 Repository가 검증합니다.
- unmatchedResults가 있으면 전체 실패합니다. 참가자를 만들어내거나 결과를 버리지 않습니다.

## 합의한 문자열 정규화 정책
조회한 참가자의 표시 문자열에 적용합니다. 입력 Race의 문자열은 목록에서 전달한 값을 유지합니다.

| 대상 | 처리 |
| --- | --- |
| 드라이버 이름 | Repository가 필수 문자열을 보장. UseCase에서 정규화 후 빈 값이면 전체 실패 |
| 약칭·팀 이름 | Repository가 선택 문자열의 타입을 보장. UseCase에서 정규화 후 빈 값은 nil |

- 앞뒤의 공백·탭·개행을 제거합니다. 비분리 공백 등 Unicode 공백도 대상에 포함합니다.
- 문자열 내부의 공백·개행, 대소문자, 악센트, 구두점은 보존합니다. 이름을 제목 형식으로 바꾸거나 약칭을 자동으로 대문자화하지 않습니다.
- 약칭에 임의의 3글자 제한을 추가하지 않으며 이름에서 약칭을 생성하지 않습니다.

예를 들어 `"  Max Verstappen\n"`은 `"Max Verstappen"`으로 반환합니다. 공백·탭만 있는 필수 이름은 오류이며 같은 내용의 선택 문자열은 nil입니다. `"Red  Bull Racing"`의 내부 공백 2개와 `"VER"`·`"ver"`의 대소문자는 그대로 보존합니다.

## 중복과 결과 구성

정규화한 참가자 정보와 연결 결과를 드라이버 번호별로 비교하여 동일 중복은 하나로 합치고 충돌하면 전체 실패합니다. 앞뒤 공백만 다른 문자열과 nil로 정리된 선택 문자열은 같은 값으로 비교하며, 내부 공백·대소문자 차이는 유지합니다. 입력 순서나 정상 레코드의 존재를 이유로 잘못된 레코드를 숨기지 않습니다. 미사용 외부 필드는 비교하지 않습니다.

- 후보의 연결 관계를 유지하며 서로 다른 레코드의 필수 값을 짜깁기하지 않습니다.
- 참가자의 results가 비면 result는 nil입니다. 결과가 있으면 동일 중복을 합친 결과를 반환합니다.
- result가 nil인 경우와 result.position만 nil인 경우를 구분합니다. 결과 미제공을 미발표·미출발·미완주로 단정하지 않습니다.
- 순위와 세 상태는 독립적입니다. 상태가 여러 개 true여도 그대로 보존하고 모두 false여도 완주를 추정하지 않습니다.
- 제공된 순위의 공백과 서로 다른 드라이버의 같은 순위를 보존합니다. 임의 순위를 부여하지 않습니다.
- 참가자·결과가 모두 비면 입력 Race와 빈 drivers를 반환합니다. 결과만 비면 참가자를 유지합니다.
- 반환 drivers의 순서는 보장하지 않습니다. 순위순 정렬·동률 처리·그룹 구성은 Presentation 책임입니다.

목록처럼 불완전한 후보를 제외하고 나머지를 성공시키지 않습니다. 조회한 참가자의 필수 정보나 참가자·결과의 정합성에 문제가 있으면 전체 실패이며, 정상적인 선택 정보 부재와 결과 미제공은 구분합니다.

## 실패와 취소

Repository 실패를 숨기거나 빈 성공으로 바꾸지 않습니다. 정규화 후 필수 이름 부재·미연결 결과·중복 충돌 등 UseCase 규칙의 실패는 UseCase에서 발생합니다. 모든 일반 오류를 Data 계층에 두도록 요구하지 않으며 공개 계약은 구체 오류 타입을 강제하지 않습니다.

호출 취소를 Repository에 전파하고 자체 검증·정규화·중복 처리도 취소에 협조합니다. 진입 시, Repository 호출 전후, 자체 반복 처리 시작, 최종 반환 전과 일반 오류 전달 전에 취소를 확인합니다. 관찰한 취소는 CancellationError로 전달하며 일반 오류 전달 전 관찰한 호출자 취소를 우선합니다.

동기 작업의 즉시 종료나 마지막 확인부터 반환까지의 원자성을 보장하지 않습니다. 이미 반환한 결과를 소급 변경하지 않습니다. 일반 실패에 따른 하위 작업 정리의 취소가 원래 실패를 덮지 않도록 하며, 여러 실패의 고정 보고 우선순위는 보장하지 않습니다.

## 호출 관계와 검증 경계

```text
ViewModel → RaceDetailUseCase.fetchRaceDetail(race)
            → RaceDetailRepository.fetchRaceDetailCandidate(race.sessionID)
                                 ↓ RaceDetailCandidate
            참가자 정규화·중복 처리·결과 정합성 확인
ViewModel ← RaceDetail(race: 입력 Race, drivers: 정리한 참가자)
```

UseCase 검증은 Repository 대역이 제공하는 후보를 기준으로 입력 Race 보존·참가자 구성·정상 빈 참가자·실패·취소를 확인합니다. 파일 읽기나 JSON 구조는 Repository 검증 대상입니다. 화면의 표시·선택·최신 요청 보호는 [화면 상태 계약](PresentationState.md)을 따릅니다.
