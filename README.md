# RadioLap

팀 라디오를 들으며 드라이버의 레이스 상황을 되짚는 iOS 앱입니다. 라디오와 당시의 랩·순위·타이어 정보를 함께 보는 것을 목표로 합니다.

현재 레이스 목록의 모델·Repository 계약·데모 Provider·ViewModel과 테스트를 작성했습니다. 와이어프레임 기반 목록 화면을 데모 데이터와 연결했습니다. 상세 화면은 이동 확인용 임시 화면입니다. [와이어프레임 안내](docs/wireframes/README.md)에서 확인 방법과 예시를 볼 수 있습니다.

## 프로젝트 목표
팀 라디오와 당시의 랩·순위·타이어 정보를 연결해 드라이버의 레이스 상황을 되짚는 앱을 만듭니다. 이 과정에서 iOS 개발 전문성을 바탕으로 AI와 해결책을 만들고, 주요 결정과 결과를 책임지는 프로젝트 운영 능력을 보여줍니다.

- 데이터와 Repository 입출력을 먼저 합의해 구현을 병행할 수 있는 기반을 마련합니다.
- 책임과 의존 방향을 명확히 하고, 취소와 응답 순서 역전에서도 최신 요청만 반영하도록 구현·검증합니다.
- 개발자는 목적·범위·맥락·검증 기준과 최종 수용을 책임집니다. AI는 문제 정의의 보완, 대안과 실패 조건 탐색, 구현·테스트·문서 작성과 리뷰에 동료로 참여합니다.
- AI의 제안과 개발자 자신의 판단을 함께 검증하고, 수용·수정·보류한 이유를 실제 작업에서 설명할 수 있도록 합니다.
- 작업을 검토 가능한 단위로 나누고, 구현 속도와 검토·수정·재작업 부담을 함께 고려해 협업 방식을 개선합니다.

목표와 달성 여부는 구분합니다. 실제 구현·검증 결과와 한계를 근거로 성과를 설명하며, 회사에서 얻은 경험과 이 프로젝트에서 새로 구현·검증한 내용을 구분합니다.

## 화면 흐름

1. **레이스 목록** — 최신순으로 정렬된 레이스를 선택합니다.
2. **레이스 상세** — 레이스 정보와 결승 결과 순서의 드라이버 목록을 보고 드라이버를 선택합니다.
3. **드라이버 라디오** — 팀 라디오 목록에서 라디오를 선택하고 당시의 랩·순위·타이어 정보를 함께 확인합니다.

## 현재 진행 상태

- OpenF1 데이터로 화면에 필요한 정보와 라디오·레이스 상황의 연결 가능성을 확인했습니다.
- 확인한 데이터를 반영한 3개 화면의 와이어프레임을 작성했습니다.
- 와이어프레임에서 순위 없음·DNF·라디오 없음 상태를 확인할 수 있습니다.
- 레이스 목록의 데이터 계층과 ViewModel 조회·정렬·실패·재시도·취소·마지막 요청 우선 처리를 구현했습니다. 목록 화면은 상태 표시·재시도·기기 시간대 표시와 임시 상세 화면 이동을 제공합니다. 와이어프레임의 재생·대사 생성은 화면 상태를 보여주는 모형입니다.

## 프로젝트 구성과 문서 활용

| 경로 | 역할 |
| --- | --- |
| `RadioLap/` | iOS 앱 소스입니다. RaceList에 모델·계약·데모 Provider·ViewModel·목록 화면이 있습니다. |
| `RadioLap.xcodeproj/` | Xcode에서 여는 프로젝트입니다. |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 책임 분리·의존 방향·명명 규칙과 첫 화면에 적용할 구조를 정리한 설계 기준입니다. 레이스 목록에 적용했습니다. |
| [CODING_CONVENTIONS.md](CODING_CONVENTIONS.md) | 역할을 드러내는 메서드 명명과 guard 활용 기준입니다. |
| [COMMIT_CONVENTIONS.md](COMMIT_CONVENTIONS.md) | 커밋 유형·변경 단위와 계약 → 테스트 → 구현 순서에 관한 공통 규칙입니다. |
| [DOCUMENTATION.md](DOCUMENTATION.md) | Domain 모델과 Repository 계약의 한글 문서 주석 작성 규칙입니다. |
| [TESTING.md](TESTING.md) | 계약 기반 검증, AAA 구성, 가독성과 독립성에 관한 공통 테스트 작성 원칙입니다. |
| [레이스 목록 문서](RadioLap/RaceList/AGENTS.md) | 기능 폴더 안에서 문맥·Repository 계약·화면 상태·완료기준을 역할별로 관리합니다. |
| [docs/wireframes/](docs/wireframes/) | 화면 흐름·배치·예외 상태를 확인하는 와이어프레임과 한글 안내 문서입니다. |

화면을 검토할 때는 [와이어프레임 안내](docs/wireframes/README.md)를 읽고, 같은 폴더의 [HTML 파일](docs/wireframes/radio-lap.html)을 브라우저에서 여세요. 데이터 연결 기준과 미리보기의 범위·한계도 안내 문서에 정리했습니다.

이 README는 프로젝트 진행에 맞춰 실제 구현하고 확인한 내용을 추가하며 갱신합니다.

## 테스트 실행
테스트 작성·리뷰는 [공통 테스트 작성 원칙](TESTING.md)을 따릅니다.

Xcode 27에서 RadioLap.xcodeproj를 열고 RadioLap 스킴과 iOS 27 시뮬레이터를 선택한 후 Product → Test(⌘U)를 실행합니다. 앱과 테스트 타깃 모두 Swift 6 언어 모드입니다.

[데모 Provider 테스트](RadioLapTests/RaceList/Data/DemoRaceListProviderTests.swift)와 [Mapper 테스트](RadioLapTests/RaceList/Data/RaceListResponseMapperTests.swift)는 네트워크 없이 [테스트 전용 자료](RadioLapTests/RaceList/Fixtures/)와 고정 시각으로 실행합니다. 검증 기준은 [완료기준](RadioLap/RaceList/Docs/CompletionCriteria.md)을 따르며, 현재 테스트 범위에서는 파일 누락과 JSON 문법·타입 오류를 제외합니다. 실행 결과는 완료기준에 기록하지 않습니다.

[ViewModel 테스트](RadioLapTests/RaceList/Presentation/RaceListViewModelTests.swift)는 동기 `load()`·`cancel()` 계약과 연속 호출 시 마지막 요청만 반영되는지 확인합니다. 취소를 무시하는 Repository로 응답 순서를 제어하여 이전 성공·실패가 최신 상태를 덮지 않는지 공개 상태와 일정 시간의 관찰로 검증합니다.

테스트는 앱 모듈을 import하지 않고 모델·계약·Provider·DTO·Mapper·ViewModel·날짜 표시 타입의 Target Membership을 RadioLapTests에도 지정하여 직접 컴파일합니다. 파일을 복사하지 않으며, 앱 호스트 없이 실행합니다. 앱과 동일하게 Swift 6·기본 MainActor 격리·Approachable Concurrency 설정을 적용합니다.
