# 레이스 목록 화면 상태
[기능 문맥](Context.md)과 [Repository 계약](RepositoryContract.md)을 바탕으로 ViewModel의 공개 계약과 View의 책임을 정의합니다. 구현과 테스트의 검증 기준은 [완료기준](CompletionCriteria.md#viewmodel과-화면)을 따릅니다.

## ViewModel의 책임과 공개 계약
ViewModel은 목록 조회·정렬·상태 전환·취소와 요청 결과의 유효성을 관리합니다. 상태는 `RaceListState`, 공개 동작은 `RaceListViewModelProtocol`로 정의하며 구체 구현과 분리합니다. 날짜 표시와 화면 이동은 View의 책임입니다.

```swift
@MainActor
protocol RaceListViewModelProtocol: AnyObject, Observable {
    var state: RaceListState { get }
    func load()
    func cancel()
}
```

상태는 외부에서 읽기만 가능하며 변경을 관찰할 수 있습니다. 상태 변경은 MainActor 내부에서 이루어집니다. `load()`와 `cancel()`은 동기 메서드로, 조회 응답을 기다리지 않고 반환하며 오류를 외부로 던지지 않습니다.

## 상태
```swift
enum RaceListState: Equatable {
    case idle
    case loading
    case content([Race])
    case empty
    case failed(message: String)
}
```

| 상태 | 의미 |
| --- | --- |
| `idle` | 최초 조회 전 또는 조회 취소 후 |
| `loading` | 유효한 조회 진행 중 |
| `content` | 정렬된 레이스가 한 건 이상 있음 |
| `empty` | 정상 조회했으나 조건에 맞는 레이스가 없음 |
| `failed` | 조회 실패와 사용자 안내 메시지 |
목록은 content 안에서만 보관하며 목록·로딩·오류를 별도 상태로 중복 관리하지 않습니다. 빈 배열은 content([])가 아닌 empty로 표현합니다.

## 초기화와 조회 의존성
다음은 구체 구현인 `RaceListViewModel`의 의존성 주입 인터페이스이며, 프로토콜의 초기화 요구사항은 아닙니다.

```swift
init(
    repository: any RaceListRepository,
    now: @escaping () -> Date = Date.init
)
```

- 초기 상태는 idle이며 초기화만으로 Repository나 now를 호출하지 않습니다.
- 주입받은 Repository 계약을 사용하며 구체적인 Provider를 생성하거나 API 응답을 직접 처리하지 않습니다.
- 조회 시즌은 2026으로 고정합니다. 조회 대상 선별과 종료 판단은 Repository 계약을 따릅니다.

## 조회와 결과 반영
`load()`는 모든 상태에서 새 조회를 시작하고 즉시 loading으로 전환합니다. 최초 조회와 실패 후 재시도에 같은 메서드를 사용하며, content·empty·failed에서도 새로 조회합니다.

- `load()` 호출마다 now를 한 번 읽습니다. 실행 전에 취소되는 조회도 동일합니다.
- Repository에는 `year: 2026`과 해당 호출에서 읽은 기준 시각을 `endedBefore`로 전달합니다.
- 실행 전에 취소된 조회는 Repository를 호출하지 않습니다.
- 진행 중인 조회가 있으면 이전 요청을 취소하고 새 요청을 시작합니다. 이전 요청이 취소를 무시해도 새 조회를 시작할 수 있습니다.

마지막 유효 요청의 결과를 다음과 같이 반영합니다.

| 결과 | 상태 처리 |
| --- | --- |
| 레이스 있음 | startsAt 내림차순, 동률은 sessionID 오름차순으로 정렬해 content로 전환 |
| 빈 배열 | empty로 전환 |
| 일반 오류 | “레이스 목록을 불러오지 못했습니다. 다시 시도해주세요.”라는 메시지의 failed로 전환 |
| Repository가 CancellationError 반환 | 실패 안내 없이 idle로 전환 |

```text
모든 상태 → load → loading ─┬→ content
                            ├→ empty
                            ├→ failed
                            └→ idle (Repository의 CancellationError)

loading → load → 이전 요청 취소 + 새 조회
loading → cancel → idle
```

## 취소와 늦은 응답
- 진행 중인 요청이 있을 때 `cancel()`을 호출하면 취소를 전달하고 즉시 idle로 전환합니다. 이후 `load()`로 다시 조회할 수 있습니다.
- 진행 중인 요청이 없으면 `cancel()`은 현재 상태를 유지합니다.
- 응답 순서와 관계없이 마지막 유효 요청만 결과를 반영합니다. 취소된 요청의 성공·일반 오류·CancellationError는 현재 상태를 변경하지 않습니다.
- 이전 요청이 늦게 끝나도 현재 요청을 취소할 수 있어야 합니다.
- 취소는 Repository 작업의 즉시 종료를 보장하지 않습니다. Repository가 취소를 무시하면 실제 응답까지 작업이 계속될 수 있으나 그 결과는 반영하지 않습니다.
- 호출 작업의 취소는 조회를 자동으로 취소하지 않습니다. 이미 취소된 호출 작업에서도 `load()`는 새 조회를 시작하며, 조회 취소는 명시적인 `cancel()`로 전달합니다.

## View의 책임
### 조회 시점과 상태 표시
- 화면 진입 시 `load()`를 호출하고, 화면이 사라질 때 `cancel()`을 호출합니다.
- loading에서는 “레이스를 불러오는 중입니다”와 진행 표시를 보여줍니다.
- content에서는 레이스 목록을 표시하고 선택할 수 있게 합니다.
- empty에서는 “2026 시즌에 조회할 수 있는 종료된 결승이 없습니다”를 표시합니다.
- failed에서는 상태의 안내 메시지와 “다시 시도” 버튼을 표시하고, 버튼 선택 시 `load()`를 호출합니다.

### 화면 표시와 이동
- 날짜와 시간은 startsAt에 사용자 기기의 시간대를 적용해 표시합니다. 개최지 시차를 적용하거나 Race.startsAt을 변경하지 않습니다.
- 날짜 경계와 서머타임을 포함해 대상 시각의 시간대 규칙을 적용합니다.
- 기기 시간대 변경 후 다시 표시할 때 현재 시간대로 표현하며, 정렬과 Race.startsAt을 유지하고 추가 조회하지 않습니다.
- 장소가 없으면 “장소 정보 없음”으로 표시하며 다른 레이스는 정상 표시합니다.
- 레이스 선택과 화면 이동 상태는 View가 소유하고, 선택한 sessionID에 해당하는 상세 화면으로 진입합니다. 목록 조회 상태에는 선택·이동 상태를 포함하지 않으며, 목록에서 드라이버 결과나 라디오를 미리 조회하지 않습니다.
