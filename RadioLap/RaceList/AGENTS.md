# 레이스 목록 작업 안내

사용자에게 제공하려는 경험과 그 이유는 [README](README.md)를 참고합니다. 이 문서는 레이스 목록 작업의 범위·제약과 확인할 문서를 안내합니다.

## 현재 작업 범위
- 조회 시즌은 2026으로 고정합니다. 후보 데이터 제공은 Repository 계약, 선별·정제·정렬은 UseCase 계약, 화면 상태와 선택 후 이동은 화면 상태 계약을 따릅니다.
- 최초 조회와 실패 후 재시도를 다룹니다. 연도 선택, 페이지네이션, 사용자 조작에 의한 새로고침은 현재 범위에 포함하지 않습니다.
- 목록에 필요한 정보만 조회합니다. 드라이버 결과와 라디오 조회는 다음 화면의 책임입니다.
- 레이스 선택 후 상세 화면으로 이동하는 연결을 다룹니다. 상세 화면 자체의 구현은 별도 기능의 범위입니다.

## 현재 연결 상태
목록의 이동 대상은 현재 이동 확인용 임시 상세 화면입니다. 이 연결 상태를 상세 기능의 구현·검증 완료로 해석하지 않습니다.

Repository는 후보를 반환하고, RaceListInteractor는 선별·정제·정렬을 수행합니다. ViewModel은 UseCase를 주입받고 RaceListPresentation 계약으로 화면에 연결됩니다. 책임별 테스트는 Repository·UseCase·ViewModel 수트로 구성하며, 코드와 테스트의 존재를 검증 통과로 해석하지 않습니다.

## 작업별 제약사항
- 공통 구조와 의존 방향은 [아키텍처](../../docs/ARCHITECTURE.md)를 따릅니다.
- Swift 코드 작성·리뷰 시 [코드 작성 규칙](../../docs/CODING_CONVENTIONS.md)의 명명과 guard 활용 기준을 따릅니다.
- Domain 모델과 Repository 계약의 문서 주석은 [공통 문서화 규칙](../../docs/DOCUMENTATION.md)을 따릅니다.
- 테스트 작성·리뷰 시 [공통 테스트 작성 원칙](../../docs/TESTING.md)을 따릅니다.
- 화면 검토 시 [와이어프레임 안내](../../docs/WIREFRAMES.md)를 읽고 연결된 HTML을 확인합니다.
- 데이터 모델·Repository·Provider 작업: [Repository 계약](Docs/RepositoryContract.md)을 읽습니다.
- UseCase·Interactor와 목록 제공 규칙 작업: [UseCase 계약](Docs/UseCaseContract.md)을 읽습니다. 후보 모델을 바꾸는 경우 Repository 계약도 확인합니다.
- ViewModel·View 작업: [화면 상태](Docs/PresentationState.md)를 읽습니다. 조회 입출력을 바꾸는 경우 UseCase·Repository 계약도 확인합니다.
- 기능 범위를 바꾸는 작업: README의 목적, 이 문서의 작업 범위와 영향을 받는 계약을 먼저 확인합니다.
- 공통 규칙은 이 문서에 복제하지 않습니다. 작업에 관련된 문서를 읽고, 동작 변경 시 해당 문서와 완료기준을 함께 갱신합니다.
- 앱 기능 구현·빌드·테스트는 사용자가 승인한 범위에서 진행합니다.
- README, 이 파일과 Docs의 문서는 앱 타깃에서 제외합니다. 문서를 추가·이동·삭제하면 Xcode 동기화 그룹의 제외 목록도 맞춥니다.

## 완료기준
[완료기준](Docs/CompletionCriteria.md)의 해당 작업 영역을 확인합니다. 기준과 실제 검증 결과를 구분하고, 실행하지 않은 검증은 완료로 표시하지 않습니다.
