# 레이스 목록 작업 안내

## 문맥
기능 범위는 [문맥](Docs/Context.md), 공통 구조와 의존 방향은 [아키텍처](../../ARCHITECTURE.md)를 따릅니다. 현재 Domain 모델·Repository 계약·데모 Provider·ViewModel의 조회·취소·늦은 응답 처리와 테스트를 구현했습니다. 와이어프레임 기반 목록 화면과 데모 의존성 연결을 구현했으며, 상세 화면은 이동 확인용 임시 화면입니다.

## 작업별 제약사항
- Swift 코드 작성·리뷰 시 [코드 작성 규칙](../../CODING_CONVENTIONS.md)의 명명과 guard 활용 기준을 따릅니다.
- Domain 모델과 Repository 계약의 문서 주석은 [공통 문서화 규칙](../../DOCUMENTATION.md)을 따릅니다.
- 테스트 작성·리뷰 시 [공통 테스트 작성 원칙](../../TESTING.md)을 따릅니다.
- 데이터 모델·Repository·Provider 작업: [Repository 계약](Docs/RepositoryContract.md)을 읽습니다.
- ViewModel·View 작업: [화면 상태](Docs/PresentationState.md)를 읽습니다. 데이터 계약을 바꾸는 경우 Repository 계약도 확인합니다.
- 기능 범위를 바꾸는 작업: 문맥과 영향을 받는 계약을 먼저 확인합니다.
- 공통 규칙은 이 문서에 복제하지 않습니다. 작업에 관련된 문서를 읽고, 동작 변경 시 해당 문서와 완료기준을 함께 갱신합니다.
- 앱 기능 구현·빌드·테스트는 사용자가 승인한 범위에서 진행합니다.
- 이 파일과 Docs의 문서는 앱 타깃에서 제외합니다. 문서를 추가·이동·삭제하면 Xcode 동기화 그룹의 제외 목록도 맞춥니다.

## 완료기준
[완료기준](Docs/CompletionCriteria.md)의 해당 작업 영역을 확인합니다. 기준과 실제 검증 결과를 구분하고, 실행하지 않은 검증은 완료로 표시하지 않습니다.
