//
//  OpenF1RequestTests.swift
//  RadioLapTests
//

import Foundation
import Testing

@MainActor
struct OpenF1RequestTests {
    @Test("쿼리의 CodingKeys·특수문자·정수 값을 보존하고 nil을 생략한다", arguments: [Int.min, Int.max])
    func encodesTypedQuery(_ number: Int) async throws {
        // Arrange
        let query = Query(sessionName: "Race & Sprint=한글?#%+", number: number, omitted: nil)
        let client = OpenF1Client { request in
            let url = try #require(request.url)
            let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
            #expect(components.scheme == "https")
            #expect(components.host == "api.openf1.org")
            #expect(components.path == "/v1/sessions")
            #expect(components.fragment == nil)
            let items = try #require(components.queryItems)
            #expect(items.count == 2)
            #expect(items.contains(URLQueryItem(name: "session_name", value: query.sessionName)))
            #expect(items.contains(URLQueryItem(name: "number", value: String(number))))
            return success(request)
        }
        // Act / Assert
        _ = try await client.request(OpenF1Request(path: .sessions, query: query))
    }

    @Test("조회 조건이 없으면 빈 쿼리 구분자와 본문을 만들지 않는다", arguments: [false, true])
    func omitsEmptyQuery(_ useEmptyObject: Bool) async throws {
        // Arrange
        let client = OpenF1Client { request in
            #expect(request.url?.absoluteString == "https://api.openf1.org/v1/meetings")
            #expect(request.httpMethod == "GET")
            #expect(request.httpBody == nil)
            #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
            return success(request)
        }
        let query: (any Encodable & Sendable)? = useEmptyObject ? EmptyQuery() : nil
        // Act / Assert
        _ = try await client.request(OpenF1Request(path: .meetings, query: query))
    }

    @Test("POST 요청의 헤더와 Encodable 본문을 JSON으로 조립한다")
    func encodesBody() async throws {
        // Arrange: 네트워크로 전송하지 않는 요청 조립 검증이다.
        let body = Body(message: "교신 & 확인", numbers: [1, 2])
        let client = OpenF1Client { request in
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "X-Test") == "value")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            let data = try #require(request.httpBody)
            #expect(try JSONDecoder().decode(Body.self, from: data) == body)
            return success(request)
        }
        // Act / Assert
        _ = try await client.request(OpenF1Request(path: .teamRadio, method: .post,
                                                   headers: ["X-Test": "value"], body: body))
    }

    @Test("배열·중첩 객체·Boolean·소수 쿼리를 임의로 문자열화하지 않는다", arguments: [0, 1, 2, 3])
    func rejectsUnsupportedQuery(_ kind: Int) async {
        // Arrange
        let client = OpenF1Client { request in
            Issue.record("지원하지 않는 쿼리가 전송되었습니다")
            return success(request)
        }
        let query: any Encodable & Sendable
        switch kind {
        case 0: query = [1, 2]
        case 1: query = ["nested": ["key": "value"]]
        case 2: query = ["boolean": true]
        default: query = ["fraction": 1.5]
        }
        // Act / Assert
        await #expect(throws: OpenF1Client.RequestError.unsupportedQuery) {
            try await client.request(OpenF1Request(path: .meetings, query: query))
        }
    }

    @Test("본문 인코딩 실패를 전달하고 전송하지 않는다")
    func propagatesEncodingFailure() async {
        // Arrange
        let client = OpenF1Client { request in
            Issue.record("인코딩에 실패한 본문이 전송되었습니다")
            return success(request)
        }
        // Act / Assert
        await #expect(throws: EncodingFailure.self) {
            try await client.request(OpenF1Request(path: .teamRadio, method: .post, body: InvalidBody()))
        }
    }

    @Test("이미 취소된 요청은 조립·전송 전에 취소를 전달한다")
    func skipsCancelledRequest() async {
        // Arrange
        let client = OpenF1Client { request in
            Issue.record("취소된 요청이 전송되었습니다")
            return success(request)
        }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await client.request(OpenF1Request(path: .meetings))
        }
        // Act / Assert
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}

private nonisolated struct Query: Encodable, Sendable {
    let sessionName: String
    let number: Int
    let omitted: String?

    enum CodingKeys: String, CodingKey {
        case sessionName = "session_name"
        case number, omitted
    }
}

private nonisolated struct EmptyQuery: Encodable, Sendable {}

private nonisolated struct Body: Codable, Equatable, Sendable {
    let message: String
    let numbers: [Int]
}

private nonisolated enum EncodingFailure: Error { case expected }

private nonisolated struct InvalidBody: Encodable, Sendable {
    func encode(to encoder: any Encoder) throws { throw EncodingFailure.expected }
}

private nonisolated func success(_ request: URLRequest) -> (Data, URLResponse) {
    (Data("[]".utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
}
