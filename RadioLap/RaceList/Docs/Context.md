# 레이스 목록 문맥
레이스 목록의 기능 범위를 정의합니다.

2026 시즌의 종료된 결승을 최신순으로 보여주고, 사용자가 레이스를 선택하면 상세 화면으로 이동합니다.
첫 화면에서는 목록에 필요한 정보만 조회하며, 드라이버 결과와 라디오 조회는 다음 화면의 책임입니다.

현재 범위는 최초 조회와 실패 후 재시도입니다. 연도 선택, 페이지네이션, 새로고침은 포함하지 않습니다.

## 관련 문서
- [공통 아키텍처](../../../ARCHITECTURE.md)
- [와이어프레임 안내](../../../docs/wireframes/README.md)
- [Repository 계약](RepositoryContract.md)
- [화면 상태](PresentationState.md)
- [완료기준](CompletionCriteria.md)
