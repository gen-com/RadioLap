# 드라이버 라디오 Repository 계약 초안

[기능 목적](../README.md)과 [작업 범위](../AGENTS.md)를 바탕으로 자료 요청·응답 해석·Domain 모델 변환의 경계를 정의합니다. 중복·충돌 처리와 시점 연결은 [UseCase 계약](UseCaseContract.md)의 책임입니다. 문서의 합의와 구현·검증 상태는 구분합니다.

## 책임과 입출력

하나의 Repository에 네 개의 독립적인 조회를 둡니다. 자료 모델·DriverRadioRepository와 DemoDriverRadioProvider를 작성했으며 JSON 입력 기반 Repository 테스트가 통과했습니다. 실제 화면 연결과 API 연동 완료를 뜻하지 않습니다.

```swift
protocol DriverRadioRepository: Sendable {
    func fetchRadioRecords(sessionID: Int, driverNumber: Int) async throws -> [RadioRecord]
    func fetchLaps(sessionID: Int, driverNumber: Int) async throws -> [DriverLap]
    func fetchPositions(sessionID: Int, driverNumber: Int) async throws -> [DriverPosition]
    func fetchStints(sessionID: Int, driverNumber: Int) async throws -> [DriverStint]
}
```

모든 메서드의 sessionID는 선택한 레이스의 세션, driverNumber는 해당 세션의 선택한 드라이버입니다. 이름·순위로 식별하지 않고 식별자에 별도의 숫자 범위 제한을 두지 않습니다. Race와 RaceDriver 전체는 Repository에 전달하지 않으며, 기본 정보나 최종 결과를 다시 조회하지 않습니다.

각 메서드는 자기 자료만 읽습니다. 정상 빈 결과는 빈 배열이며 읽기·해석 실패를 빈 배열로 바꾸지 않습니다. 배열 순서와 중복 제거는 보장하지 않습니다. 다른 종류의 조회, 시점 연결, 오디오 다운로드·재생과 재생 가능 여부의 사전 접속 검사는 수행하지 않습니다.

## 반환 모델과 정보 보존

반환 모델은 외부 DTO와 독립적인 Domain 값입니다. 저장 속성은 let이며 Equatable·Sendable로 구성합니다. 중복 제거 전후에 필드 의미와 필수성이 같으므로 별도 후보·최종 타입을 복제하지 않습니다.

| 모델 | 속성과 타입 | 의미 |
| --- | --- | --- |
| RadioRecord | recordedAt: Date, recordingURL: URL | 라디오 기록 절대 시각과 원격 오디오 주소 |
| DriverLap | number: Int, startsAt: Date?, duration: TimeInterval? | 랩 번호, 시작 절대 시각과 소요 시간(초). 선택 값의 nil은 누락·null |
| DriverPosition | recordedAt: Date, position: Int | 순위 기록 절대 시각과 제공된 순위 |
| DriverStint | startLap: Int?, endLap: Int?, compound: String? | 타이어 사용 시작·종료 랩과 컴파운드. nil은 해당 정보의 부재 |

요청한 세션·드라이버와의 일치는 Repository에서 확인하므로 반환 레코드에 두 식별자를 반복 저장하지 않습니다. 동일·상충 중복, 선택 값 부재, 빈 문자열·공백 문자열을 보존합니다. Repository는 누락·null을 nil로 변환하며, UseCase는 컴파운드의 공백뿐인 값도 nil로 정리합니다. 따라서 공유 모델의 compound가 nil이라는 사실만으로 원본 필드의 누락·null 여부를 판단하지 않습니다. 랩 소요 시간이나 스틴트 범위가 구간을 구성할 수 있는지는 Domain에서 판단합니다. Repository가 값을 보정하거나 레코드를 제외하지 않습니다.

## 요청 대상과 필드 매핑

외부 자료는 team_radio·laps·position·stints이며 요청 드라이버를 선택한 응답의 session_key와 driver_number를 요청 입력과 대조합니다. 세션 전체 파일의 선택 전 검증은 아래 데모 공급 기준을 따릅니다. 요청과 다른 세션 또는 드라이버가 섞이면 해당 조회 전체를 실패시킵니다. 정상 레코드가 함께 있어도 조용히 제외하지 않습니다. meeting_key는 연결·검증에 사용하지 않습니다.

| 자료 | 원본 필드 | 변환 또는 확인 |
| --- | --- | --- |
| 공통 | session_key · driver_number | 요청 대상 일치 확인 |
| team_radio | date · recording_url | recordedAt · recordingURL |
| laps | lap_number · date_start · lap_duration | number · startsAt · duration |
| position | date · position | recordedAt · position |
| stints | lap_start · lap_end · compound | startLap · endLap · compound |

세션·대회·참가자·최종 결과나 미사용 필드로 누락을 보충하지 않습니다. 스틴트의 stint_number·tyre_age_at_start와 랩의 섹터·속도 정보는 현재 연결에 사용하지 않습니다.

## 합의한 해석 기준

아래는 앱의 수용 정책이며 표본의 필드 존재를 모든 API 응답의 보장으로 해석하지 않습니다.

| 필드 | 허용 조건 |
| --- | --- |
| 공통 session_key · driver_number | 필수 정수. 요청 입력과 일치해야 함 |
| team_radio.date · recording_url | 각각 필수 시각 문자열·URL 문자열 |
| laps.lap_number | 필수 정수 |
| laps.date_start · lap_duration | 각각 선택 시각 문자열·초 단위 숫자 |
| position.date · position | 각각 필수 시각 문자열·정수 |
| stints.lap_start · lap_end · compound | 각각 선택 정수·정수·문자열 |

- 필수 필드의 누락·null은 해당 조회 실패입니다. 기본값으로 보충하지 않습니다.
- 랩 시작 시각·소요 시간, 스틴트 시작·종료 랩·컴파운드는 선택 정보입니다. 누락과 null을 구분하지 않고 nil로 보존합니다.
- 값이 있는데 잘못된 타입이거나 날짜를 해석할 수 없으면 해당 조회 전체가 실패합니다. 선택 값이라는 이유로 해석 실패를 nil로 바꾸지 않습니다.
- 날짜는 Z 또는 UTC 오프셋이 있는 ISO 8601 시각을 받고 소수 초 유무 모두 수용합니다. 시차가 없으면 기기 시간대로 추정하지 않고 실패합니다. 시차를 반영해 같은 순간은 같은 Date로 변환하며 표시 시간대는 Presentation에서 다룹니다. 자릿수·소수 초 길이에 불필요한 제한을 추가하지 않습니다.
- 오디오 주소는 호스트가 있는 HTTP·HTTPS URL이어야 합니다. 앞뒤 공백이나 잘못된 주소를 자동 보정하지 않습니다. 주소 형식 문제는 라디오 조회 실패이고, 형식이 유효한 주소의 실제 접속·재생 실패는 재생 책임에서 처리합니다. 경로·쿼리를 임의 정규화하거나 제거하지 않으며 검증한 URL의 문자열 표현을 중복 판단과 정렬에 사용합니다.
- 컴파운드는 문자열로 보존하며 알려진 종류만 허용하는 열거형으로 제한하지 않습니다. 앞뒤 공백 정규화는 Domain에서 수행합니다.
- 랩 번호·순위·드라이버 번호에 근거 없는 최솟값·최댓값을 적용하지 않습니다.

정수는 Swift Int로 표현 가능한 정수 값입니다. 문자열·Boolean·소수 부분이 있는 값을 정수로 변환하지 않습니다. 소요 시간은 TimeInterval로 표현 가능한 유한한 숫자이며 문자열·Boolean은 변환하지 않습니다. 0 이하 소요 시간과 역전된 스틴트 범위도 보존하고 구간 유효성은 Domain에서 판단합니다.

최상위 JSON은 배열이고 각 원소는 객체여야 합니다. 파일 전체의 구조·식별자 오류와 선택한 드라이버 레코드의 사용 필드 해석 오류는 해당 조회 전체 실패입니다. 미사용 필드와 알 수 없는 필드는 무시합니다.

## 독립적인 실패와 취소

자료 읽기·응답 해석·요청 대상 불일치로 실패하면 해당 메서드가 오류를 전달합니다. 잘못된 레코드를 제거한 부분 성공이나 정상 빈 결과로 바꾸지 않습니다. 다른 메서드의 성공 결과는 변경하지 않습니다. 네 조회를 모두 성공해야 반환하는 단일 작업으로 묶지 않습니다.

조회 전, 읽기·해석 후, 반환 전에 취소를 확인하고 관찰한 취소는 CancellationError로 전달합니다. 일반 오류를 전달하기 직전에 호출 취소가 관찰되면 CancellationError를 전달하며, 관찰되지 않으면 원래 오류를 전달합니다. 이미 반환한 결과는 뒤늦은 취소로 바꾸지 않습니다. 일반 오류와 취소를 정상 빈 결과로 숨기지 않습니다.

한 조회의 실패 때문에 다른 종류의 조회를 취소하지 않습니다. 늦은 결과의 화면 반영 차단과 요청별 재시도는 ViewModel 책임입니다. 동기 읽기·해석 도중의 즉시 중단이나 마지막 취소 확인 이후 반환까지의 원자성을 보장하지 않습니다.

## 데모 공급과 공식 근거

이번 구현은 JSON 파일을 입력으로 사용합니다. 실제 API Provider는 이번 범위에 포함하지 않으며, 데모 자료 수집을 위한 공개 API 읽기와 앱의 실제 API 연동은 구분합니다.

지원 세션은 11388이며 지원 드라이버 번호는 1, 3, 5, 6, 10, 11, 12, 14, 16, 18, 23, 27, 30, 31, 41, 43, 44, 55, 63, 77, 81, 87입니다. 현재 상세 데모의 전체 참가자 22명과 일치합니다. 이 목록은 데모 공급 설정이며 제품의 드라이버 선택 제한이나 식별자 허용 범위가 아닙니다. 지원 여부를 라디오 기록 존재로 판단하지 않습니다.

세션 전체 원본 응답을 다음 파일에 보관합니다. 내용은 재직렬화하거나 수정하지 않으며 드라이버별로 파일을 복제하지 않습니다.

| 파일 | 원본 요청 |
| --- | --- |
| [team_radio-11388.json](../Data/Fixtures/team_radio-11388.json) | [team_radio?session_key=11388](https://api.openf1.org/v1/team_radio?session_key=11388) |
| [laps-11388.json](../Data/Fixtures/laps-11388.json) | [laps?session_key=11388](https://api.openf1.org/v1/laps?session_key=11388) |
| [position-11388.json](../Data/Fixtures/position-11388.json) | [position?session_key=11388](https://api.openf1.org/v1/position?session_key=11388) |
| [stints-11388.json](../Data/Fixtures/stints-11388.json) | [stints?session_key=11388](https://api.openf1.org/v1/stints?session_key=11388) |

파일은 한 세션의 여러 드라이버를 포함하는 공급 자료입니다. 데모 공급과 응답 해석의 검증 경계는 다음과 같습니다.

1. 파일 전체의 JSON 배열·객체 구조, 각 레코드의 session_key·driver_number 해석 가능 여부와 요청 세션 일치를 확인합니다. 문제가 있으면 해당 조회 전체를 실패시킵니다.
2. 식별자가 정상인 레코드에서 요청 드라이버의 자료를 선택합니다. 다른 드라이버의 레코드가 있다는 이유로 실패시키지 않습니다.
3. 선택한 레코드의 날짜·URL·랩·순위·스틴트 필드를 위 해석 기준에 따라 검증합니다. 오류가 있으면 해당 조회 전체를 실패시킵니다. 다른 드라이버의 비식별자 필드 오류는 현재 조회에 영향을 주지 않습니다.

예를 들어 드라이버 3을 요청할 때 드라이버 44의 날짜 오류는 제외 대상 자료의 오류이지만, 드라이버 번호 자체를 해석할 수 없는 레코드는 선택 대상 여부를 판단할 수 없으므로 조회 실패입니다. 선택된 응답에 요청과 다른 세션·드라이버가 있으면 요청 대상 불일치 실패를 적용합니다. 이는 공급·해석 책임의 구분이며 별도 타입이나 계층 추가를 요구하지 않습니다.

지원하는 세션·드라이버의 해당 기록이 없으면 정상 빈 배열입니다. 미지원 세션·드라이버는 자료 미지원 실패이며 빈 결과로 바꾸지 않습니다. 파일 누락·읽기·해석 실패도 해당 조회 실패입니다. 지원 목록을 얻기 위해 상세의 참가자 파일을 런타임에 다시 읽지 않습니다. 공급 단계의 파일 구조·식별자 해석 문제를 조용히 제외하여 정상 빈 결과로 만들지 않습니다.

- [Team radio](https://openf1.org/docs/#team-radio): 기록 시각과 recording_url을 제공합니다. API 시각을 실제 발화 시각과 동일하다고 단정하거나 파일명에서 발화 시각을 추출하지 않습니다.
- [Laps](https://openf1.org/docs/#laps): date_start는 근사 시작 시각, lap_duration은 초 단위 소요 시간입니다. 별도 종료 시각 대신 Domain에서 두 값을 이용해 구간을 구성합니다.
- [Position](https://openf1.org/docs/#position): 세션 중 순위 기록을 제공합니다. 상세의 최종 결과와 구분합니다.
- [Stints](https://openf1.org/docs/#stints): 시작 랩·마지막 완료 랩과 컴파운드를 제공합니다.

## 검증 경계와 후속 작업

Repository 검증은 요청 입력, 외부 응답 해석·변환, 부재와 중복 보존, 요청 대상 확인, 독립적인 빈 결과·실패·취소를 대상으로 합니다. 중복 통합·충돌·정렬·시점 연결은 UseCase 검증으로 나눕니다.

데모의 정상·빈 결과는 저장한 원본 자료로 확인하고, 오류·충돌·취소는 별도 테스트 자료와 대역으로 검증합니다. 입력 해석·데모 공급 기준의 합의와 완료기준·테스트·구현 완료를 구분합니다.

Repository 테스트와 자료는 [테스트 디렉토리](../../../RadioLapTests/DriverRadio/)에 작성했습니다. 테스트는 Repository 메서드의 반환 모델·오류를 검증하며 JSON은 번들 입력 자료로만 사용합니다. 자료별 공급 함수는 테스트 준비 단계에서 주입합니다. Provider와 앱 선언을 테스트 타깃에 연결해 컴파일·테스트를 통과했습니다. 기본 번들 생성 경로의 원본 데모 자료를 실제 화면에서 조회하는 연결 검증은 남아 있습니다.
