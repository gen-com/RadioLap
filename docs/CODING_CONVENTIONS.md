# 코드 작성 규칙

## 명명

- 메서드 이름은 동작과 대상을 구체적으로 드러냅니다. `make`·`create` 같은 일반적인 표현보다 `decodeResponses`, `validateAndMapRaces`처럼 역할을 설명하는 이름을 사용합니다.

## guard

- 실패·제외 조건을 먼저 처리해 정상 흐름의 중첩을 줄입니다.
- 오류는 `throw`, 항목 제외는 `continue`, 정상 종료는 `return`을 사용합니다.
- 조건과 종료 동작을 한눈에 읽을 수 있으면 한 줄로 작성합니다. 조건이 길면 `else`를 다음 줄에 둡니다.
- 모든 `if`를 `guard`로 바꾸거나 기존 처리 순서를 변경하지 않습니다.

```swift
// 조건과 종료 동작을 한눈에 읽을 수 있으면 한 줄로 작성합니다.
guard !first.isCancelled else { continue }

// 긴 조건은 else를 다음 줄에 둡니다.
guard let matches = meetingsByID[session.meetingKey], let first = matches.first
else { throw DataError.missingMeeting(session.meetingKey) }
```

## SwiftUI 화면 구성

- 개발자가 화면 구조와 각 View의 역할을 이해하기 쉽게 구성합니다. `body`에는 화면의 배치와 계층이 드러나도록 하고, 의미 있는 화면 영역은 별도 `View` 타입으로 분리합니다.
- 타입 이름은 화면에서 맡는 역할을 드러냅니다.
- 단순한 요소까지 기계적으로 분리하거나, 다른 View에 값을 전달하기만 하는 중간 View를 만들지 않습니다.
- 하위 View에는 표시할 데이터와 이벤트 클로저를 전달합니다. 필요한 값과 동작만으로 충분하다면 ViewModel 전체를 전달하지 않습니다.
- 짧고 해당 화면에서만 사용하는 타입은 같은 파일에 `private`로 둡니다. 독립적인 역할이나 분량이 있어 따로 읽는 편이 명확하면 파일로 분리합니다.
- 상태 소유와 의존성의 책임은 [아키텍처](ARCHITECTURE.md#의존성-조립-규칙)를 따릅니다.

다음 예시는 상위 View에 목록 배치를 남기고, 행의 표시와 선택 이벤트를 별도 타입으로 분리합니다.

```swift
struct ItemListView: View {
    let titles: [String]
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text("항목").font(.title)
            ForEach(titles.indices, id: \.self) { index in
                ItemRowView(title: titles[index]) {
                    onSelect(index)
                }
            }
        }
    }
}

private struct ItemRowView: View {
    let title: String
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
            }
        }
    }
}
```
