# RadioLap 아키텍처

## 목적과 적용 상태

GroupCalendarDemo의 책임 분리와 의존성 주입 방식을 차용하되, RadioLap에 필요한 구조만 만듭니다. 이 문서는 합의한 설계 기준입니다.

기능별로 책임을 나누고, 실제 역할이 있는 계층과 타입만 추가합니다. 기존 프로젝트의 폴더나 코드를 기계적으로 복사하지 않습니다.

## 책임 분리

| 구분 | 책임 |
| --- | --- |
| Data | API 조회와 응답 변환을 담당하고, Domain의 Repository 계약을 구현합니다. |
| Dependency | AppComponent가 구체적인 Provider를 생성하고, 소비자가 필요한 계약으로 주입합니다. |
| Domain | 레이스·라디오 모델, Repository 계약, 화면과 독립적인 업무 규칙을 정의합니다. |
| Presentation / ViewModel | 조회·재시도 등 화면 동작을 처리하고 로딩·목록·빈 상태·오류 상태를 관리합니다. |
| Presentation / View | ViewModel의 상태를 표시하고 사용자 이벤트를 전달하며, SwiftUI 화면 이동을 소유합니다. |

## 조립 과정과 의존 방향

객체를 조립하고 사용하는 과정은 다음과 같습니다. 위아래 배치는 조립과 사용의 흐름이며, 코드 의존 방향을 뜻하지 않습니다.

```text
Data: OpenF1RaceListProvider 또는 DemoRaceListProvider
  │ AppComponent가 구현체를 생성
Dependency: AppComponent → RaceListDependency
  │ 구체적인 구현체를 Repository 계약으로 주입
Domain 계약: RaceListRepository
  │ ViewModel이 계약을 호출하고 Domain 데이터를 받음
Presentation: RaceListViewModel
  │ 처리 결과를 화면 상태로 표현
View: RaceListView
```

실제 코드 의존 방향은 다음과 같습니다.

```text
Data ──────────→ Domain
Presentation ──→ Domain

Dependency: 구체적인 Data 구현체를 선택하고 Domain 계약으로 제공
```

- Domain은 구체적인 Provider, AppComponent, 화면을 알지 못합니다.
- ViewModel은 필요한 Repository 등 준비된 계약만 보관하며, Provider를 직접 생성하지 않습니다.
- 기능 진입 View는 해당 기능의 의존성을 받아 자신의 ViewModel을 생성하고 SwiftUI 상태로 소유합니다.
- 같은 기능의 보조 View는 기존 ViewModel을 전달받아 사용할 수 있습니다.
- Component는 의존성을 조립하며, 화면 상태나 화면 이동을 소유하지 않습니다.

View 타입과 파일을 나누는 기준, 화면 배치를 드러내는 코드 작성 방식은 [SwiftUI 화면 구성 규칙](CODING_CONVENTIONS.md#swiftui-화면-구성)을 따릅니다.

## ViewModel과 업무 로직의 분리

단순한 화면은 ViewModel로 시작합니다. 조회하고 최신순으로 정렬해 표시하는 정도라면 별도의 처리 객체를 만들지 않습니다.

복잡도는 분리 시점을 판단하는 신호이며, 분리 기준은 책임입니다. 화면과 독립적인 업무 로직이 커지면 Domain으로 분리합니다. 로딩 표시, 화면 오류, 현재 화면 요청의 결과 반영 여부 등은 ViewModel이 담당합니다.

모든 기능에 Interactor를 두지 않습니다. 분리한 역할에 맞춰 이름을 붙입니다.

| 이름 | 역할 |
| --- | --- |
| `…Resolver` | 여러 정보를 해석하여 결과를 결정합니다. 예를 들어 `RadioContextResolver`는 이미 받은 데이터로 라디오 시각의 랩·순위·타이어를 결정합니다. |
| `…Policy` | 특정 판단 기준이나 규칙을 표현합니다. |
| `…Manager` | 지속되는 공유 상태와 생명주기를 관리합니다. |

여러 조회를 조율하는 객체도 실제 필요가 생길 때 추가합니다. Repository 호출을 그대로 전달하는 타입이나 빈 계층은 만들지 않습니다. 위 이름들은 역할의 예시이며, 모두 구현해야 하는 목록이 아닙니다.

## 계약과 구현체의 이름

| 이름 | 의미 |
| --- | --- |
| `…Repository` | Domain의 데이터 접근 프로토콜 |
| `…Provider` | Repository 계약의 구체적인 구현체 |
| `…Dependency` | 소비자가 필요로 하는 의존성 계약 |
| `…Component` | 구체적인 구현체를 생성·조립하는 타입 |

실제 API 구현과 데모 구현은 같은 Repository 계약을 따릅니다. 데이터 출처를 바꿔도 ViewModel이 구체적인 Provider를 알 필요가 없도록 합니다.

## 첫 화면에 적용할 구조

레이스 목록 화면은 다음 구성으로 시작합니다. 아래는 구현할 책임과 의존성의 배치입니다.

```text
RadioLap/
  App/
    Dependency/
      AppComponent.swift
  RaceList/
    AGENTS.md
    Docs/
      Context.md
      RepositoryContract.md
      PresentationState.md
      CompletionCriteria.md
    Dependency/
      RaceListDependency.swift
    Domain/
      Race.swift
      RaceListRepository.swift
    Data/
      OpenF1RaceListProvider.swift
      DemoRaceListProvider.swift
    Presentation/
      ViewModel/
        RaceListState.swift
        RaceListViewModelProtocol.swift
        RaceListViewModel.swift
      View/
        RaceListView.swift
        RaceListContentView.swift
        RaceRowView.swift
        RaceDateLabels.swift
```

`RadioLapApp`은 `RaceListView`를 직접 표시합니다. `RaceListDependency`는 목록 화면이 필요한 `RaceListRepository`를 노출합니다. `RaceListView`는 전달받은 의존성으로 ViewModel을 생성하거나 준비된 ViewModel을 전달받아 SwiftUI 상태로 소유합니다. ViewModel 프로토콜을 통해 상태를 표시하고 이벤트를 전달하며, ViewModel은 필요한 Repository만 보관합니다.

첫 화면의 흐름은 다음과 같습니다.

1. View가 화면 진입에 따라 ViewModel에 목록 조회를 요청합니다.
2. ViewModel은 로딩 상태로 전환하고 Repository를 호출합니다.
3. Provider는 API 응답 또는 데모 데이터를 `Race` 목록으로 제공합니다.
4. ViewModel은 최신순 정렬 후 목록·빈 상태·오류를 화면 상태로 표현합니다.
5. View는 상태를 표시하고, 레이스 선택 시 상세 화면으로 이동합니다.

첫 화면에는 별도 `RaceListPolicy`나 Interactor를 만들지 않습니다. 구조와 문서는 구현하며 확인된 필요에 맞춰 확장합니다.

## 문서 배치

공통 설계는 최상단 ARCHITECTURE.md에, 전체 화면 흐름과 와이어프레임은 docs/에 둡니다. 기능별 계약과 상태·완료기준은 해당 기능의 Docs/에 두고, AGENTS.md를 작업별 문서 진입점으로 사용합니다.

레이스 목록은 [작업 안내](RadioLap/RaceList/AGENTS.md)에서 필요한 문서로 이동합니다. 기능 폴더 안의 Markdown 문서는 Xcode에서 읽을 수 있지만 앱 타깃 멤버십에서 제외하며, 앱 리소스로 복사하지 않습니다. 새 문서를 추가할 때 제외 설정도 함께 확인합니다.
