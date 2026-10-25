# RadioLap

사용자가 팀 라디오를 들으며 “어떤 상황에서 나온 교신인가”를 이해할 수 있는 경험을 만듭니다.
라디오 기록 시각과 레이스 데이터를 연결해 교신 당시의 상황을 보여줍니다.

## AI와 협업
AI와의 협업은 단순히 코드를 빠르게 만드는 것을 넘어, 대안을 넓게 탐색하고 판단의 근거를 검증해 사용자에게 더 나은 경험을 제공할 수 있습니다.
개발 전문성을 바탕으로 AI와 동료로서 협업하되, 주요 결정과 결과에 대한 책임은 개발자가 보장합니다.

| 단계 | 개발자 | AI 동료 |
| --- | --- | --- |
| **목적** | 화면이 제공할 경험과 범위를 정합니다. | 필요한 정보와 예외 상황을 함께 탐색합니다. |
| **설계** | 대안을 검토하고 주요 결정과 근거를 명확히 합니다. | 대안과 실패 조건을 제안하고 설계를 검토합니다. |
| **검증 기준** | 올바른 동작과 수용 기준을 정합니다. | 기준의 누락을 검토하고 테스트로 구체화합니다. |
| **구현** | 설계 준수와 변경 필요성을 검토합니다. | 합의한 설계에 따라 코드 작성을 주로 수행합니다. |
| **검증** | 결과를 확인하고 수용·수정·보류를 결정합니다. | 테스트 실행·결과 분석·수정을 지원합니다. |

## 목적에서 검증까지
만들고자 한 경험이 어떤 설계와 구현으로 이어졌는지 살펴봅니다. 각 과정에는 개발자의 결정과 근거, AI의 기여, 검증 결과와 남은 한계를 기록합니다.

| 목적 | 설계 | 검증 기준 | 구현 | 검증 |
| --- | --- | --- | --- | --- |
| [팀 라디오와 당시 레이스 상황을 함께 살펴보기](docs/WIREFRAMES.md) | [책임과 의존 방향 설계하기](docs/ARCHITECTURE.md) | [계약에서 테스트 도출하기](docs/TESTING.md) | [AI와 구현을 진행하는 작업 지침](AGENTS.md) | — |
| [최근 열린 레이스부터 살펴보고 선택하기](RadioLap/RaceList/README.md) | [Repository 계약](RadioLap/RaceList/Docs/RepositoryContract.md) · [UseCase 계약](RadioLap/RaceList/Docs/UseCaseContract.md) · [화면 상태와 동작](RadioLap/RaceList/Docs/PresentationState.md) | [레이스 목록 완료기준](RadioLap/RaceList/Docs/CompletionCriteria.md) | [레이스 목록 코드](RadioLap/RaceList/) | [레이스 목록 테스트 코드](RadioLapTests/RaceList/) |
| [선택한 레이스의 결과를 살펴보고 드라이버 고르기](RadioLap/RaceDetail/README.md) | [Repository 계약](RadioLap/RaceDetail/Docs/RepositoryContract.md) · [UseCase 계약](RadioLap/RaceDetail/Docs/UseCaseContract.md) · [화면 상태와 동작](RadioLap/RaceDetail/Docs/PresentationState.md) | [레이스 상세 완료기준](RadioLap/RaceDetail/Docs/CompletionCriteria.md) | [레이스 상세 코드](RadioLap/RaceDetail/) | [레이스 상세 테스트 코드](RadioLapTests/RaceDetail/) |
교신이 나온 상황 되짚기 | 라디오와 레이스 시점 연결하기 | 확인 가능한 정보의 경계 정하기 | 재생과 상황 정보 연결하기 | 테스트 결과와 실제 라디오 화면 |

레이스 목록과 상세의 구현·검증 링크는 코드 위치를 안내합니다. 코드의 존재나 링크 연결은 완료기준 충족 또는 테스트 통과를 의미하지 않습니다.
