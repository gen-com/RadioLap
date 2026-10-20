# 테스트 작성 원칙

프로젝트 전반의 테스트 작성과 리뷰에 적용하는 공통 원칙입니다. 기능별 검증 항목은 해당 요구사항·계약·완료기준에서 정합니다.

## 검증 기준

- 요구사항 → 계약 → 완료기준 → 테스트 순서로 검증 항목을 도출합니다. 현재 구현이나 기존 테스트를 근거로 기준을 바꾸지 않습니다.
- 공개 입력에 대한 결과·상태 변화·오류 등 외부에서 관찰할 수 있는 동작을 검증합니다. 내부 처리 순서나 구체적인 타입은 계약에 필요한 경우에만 확인합니다.
- 정상 동작과 함께 경계 조건·빈 결과·실패 사례를 고려합니다. 검증 범위와 제외 항목은 작업별로 합의합니다.
- 기대 결과는 구현의 계산이나 변환 로직을 복제하지 않고, 합의한 동작에서 정합니다.
- 중복 검증은 줄이되 필요한 검증 범위를 유지합니다. 서로 다른 테스트가 맡는 역할을 명확히 합니다.

## AAA 구성

각 테스트는 Arrange → Act → Assert 흐름으로 작성합니다.

| 단계 | 역할 |
| --- | --- |
| Arrange — 준비 | 검증할 조건, 입력, 기대 결과를 준비합니다. |
| Act — 실행 | 검증 대상의 동작을 실행하고 결과를 받습니다. |
| Assert — 확인 | 실제 결과가 기대 결과를 충족하는지 확인합니다. |

다음은 할인 금액 계산을 검증하는 의사 코드입니다.

```text
test "할인율을 적용한 금액을 반환한다" {
    // Arrange
    price = 100
    discountRate = 0.2
    expected = 80

    // Act
    actual = calculateDiscountedPrice(price, discountRate)

    // Assert
    assert(actual == expected)
}
```

공통 준비와 정리는 모으고, 테스트별 조건은 Arrange에 둡니다. 공통 코드를 분리하더라도 해당 테스트의 입력 조건과 기대 결과는 본문에서 쉽게 파악할 수 있어야 합니다.

## Swift Testing 검증 도구

| 도구 | 사용 기준 | 실패 시 동작 |
| --- | --- | --- |
| `#expect` | 값·상태 등 일반적인 결과를 확인합니다. | 실패를 기록하고 다음 코드를 계속 실행합니다. |
| `#require` | 후속 검증에 필요한 전제조건을 확인하거나 Optional을 꺼냅니다. | 실패를 기록하고 오류를 던집니다. 잡지 않으면 현재 테스트가 중단됩니다. |
| `confirmation` | 콜백·알림 등 이벤트의 발생 횟수를 확인합니다. | 블록이 끝날 때 기대 횟수와 다르면 실패를 기록합니다. |

다음은 각 도구의 사용을 보여주는 Swift 코드 조각입니다. 값과 동작 이름은 예시입니다.

```swift
#expect(actual == expected)

// 항목이 없으면 이후 속성 검증을 진행하지 않습니다.
let item = try #require(items.first)
#expect(item.name == "Sample")

await confirmation("완료 알림", expectedCount: 1) { completed in
    // performOperation은 콜백 처리가 끝날 때까지 기다리는 예시 동작입니다.
    await performOperation(onCompletion: { completed() })
}
```

- 일반 검증에는 `#expect`를 사용하고, 조건이 충족되지 않으면 후속 검증이 무의미하거나 안전하지 않은 경우에 `#require`를 사용합니다.
- `confirmation`은 이벤트를 자동으로 기다리지 않습니다. 블록 안에서 필요한 작업을 기다리고, 발생 여부를 확인할 동작보다 먼저 콜백이나 관찰을 등록합니다.
- 이벤트가 없어야 한다면 `expectedCount: 0`을 사용합니다. 일정 시간 동안 관찰했다는 사실만으로 작업의 종료나 이후에도 이벤트가 없음을 보장하지 않습니다.

자세한 API는 [검증과 확인](https://developer.apple.com/documentation/testing/expectations), 비동기 대기의 차이는 [XCTest에서 이전하기](https://docs.swift.org/latest/documentation/testing/migratingfromxctest/)를 참고합니다.

### 오류 검증: `#expect(throws:)`

오류 발생이 기대 동작일 때 사용합니다. 오류가 없거나 기대와 다른 오류가 발생하면 실패를 기록합니다. 오류 타입이나 값은 계약에서 보장하는 범위까지만 검증합니다.

```swift
// validate는 입력을 검사하는 예시 동작입니다.
#expect(throws: ValidationError.self) {
    try validate("")
}
```

정상 동작을 검증할 때는 일반적으로 `throws` 테스트에서 `try`로 실행하면 충분합니다. 예상하지 못한 오류가 전파되면 테스트가 실패합니다. 자세한 내용은 [오류 검증](https://developer.apple.com/documentation/testing/testing-for-errors-in-swift-code)을 참고합니다.

### 직접 실패 기록: `Issue.record`

예상하지 못한 분기처럼 조건식으로 표현하기 어려운 실패를 기록할 때 사용합니다. 기록만으로 실행을 중단하지 않으므로, 후속 검증이 불가능하면 `return` 등으로 흐름을 종료합니다. 조건식이나 Optional로 표현할 수 있다면 `#expect` 또는 `#require`를 우선합니다.

```swift
// result는 성공을 기대하는 예시 결과입니다.
switch result {
case .success(let value):
    #expect(value == expected)
case .failure(let error):
    Issue.record("예상하지 못한 실패: \(error)")
    return
}
```

### 매개변수 테스트: `@Test(arguments:)`

같은 동작과 검증을 여러 입력에 적용할 때 사용합니다. 입력별로 사례가 구분되므로 어떤 조건에서 실패했는지 확인하기 쉽습니다. 검증 목적이나 준비 과정이 크게 다르면 별도 테스트로 나눕니다.

```swift
@Test("이름 앞뒤의 공백을 제거한다", arguments: [" Sample", "Sample ", " Sample "])
func trimsName(_ input: String) {
    // Arrange
    let expected = "Sample"

    // Act
    let actual = normalizeName(input)

    // Assert
    #expect(actual == expected)
}
```

`normalizeName`은 이름을 정리하는 예시 동작입니다. 자세한 내용은 [매개변수 테스트](https://developer.apple.com/documentation/testing/parameterizedtesting)를 참고합니다.

## 가독성과 신뢰성

- 테스트 이름으로 조건과 기대 동작을 드러냅니다. 한 테스트는 하나의 명확한 검증 목적을 가집니다.
- Swift Testing에서는 목적 설명을 별도 주석 대신 `@Test("조건과 기대 동작")`에 작성합니다. AAA 주석과 준비 조건·보조 코드에 필요한 설명은 유지합니다.
- 테스트 자료는 목적과 기대 결과를 쉽게 이해할 수 있도록 구성합니다.
- 테스트는 다른 테스트의 실행 순서나 변경한 상태에 의존하지 않으며, 같은 조건에서 반복 가능한 결과를 내야 합니다.
- 공유 상태를 변경해야 한다면 다른 테스트에 미치는 영향을 통제하고, 성공·실패와 관계없이 원래 상태로 복원합니다. 필요한 자원 정리도 보장합니다.
- 보조 메서드와 타입은 반복을 줄이고 의도를 드러내는 만큼만 사용합니다. 불필요한 추상화나 간접 단계를 만들지 않습니다.
- 실제 결함이 있어도 통과할 수 있는 검증문을 피합니다. 필요한 경우 항목의 존재·개수·값을 함께 확인하고, 계약에 없는 순서는 강제하지 않습니다.

## 완료 판단

완료기준과 실행 결과를 구분합니다. 테스트 코드의 존재만으로 검증 완료를 판단하지 않으며, 실행하지 않은 검증은 완료로 표시하지 않습니다. 실행 날짜·통과 개수·소요 시간 같은 기록은 공통 원칙과 완료기준 문서에 남기지 않습니다.
