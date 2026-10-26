//
//  OpenF1Client.swift
//  RadioLap
//

import Foundation

/// OpenF1의 HTTP 요청·상태 확인·전송 취소를 처리한다. 응답 해석은 기능별 Provider가 맡는다.
nonisolated struct OpenF1Client: Sendable {
    enum RequestError: Error, Equatable {
        case invalidURL
        case unsupportedQuery
        case nonHTTPResponse
        case httpStatus(Int)
    }

    private static let requestTimeout: TimeInterval = 30
    private static let resourceTimeout: TimeInterval = 60

    private let send: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    init(send: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) {
        self.send = send
    }

    /// 앱 수명 동안 공유할 세션. 응답 캐시와 인증 상태를 디스크에 저장하지 않는다.
    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = Self.requestTimeout
        configuration.timeoutIntervalForResource = Self.resourceTimeout
        let session = URLSession(configuration: configuration)
        self.init { try await session.data(for: $0) }
    }

    func request(_ request: OpenF1Request) async throws -> Data {
        do {
            try Task.checkCancellation()
            let urlRequest = try urlRequest(for: request)
            try Task.checkCancellation()
            let (data, response) = try await send(urlRequest)
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse else { throw RequestError.nonHTTPResponse }
            guard (200..<300).contains(response.statusCode) else { throw RequestError.httpStatus(response.statusCode) }
            return data
        } catch {
            try Task.checkCancellation()
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            throw error
        }
    }

    private func url(for request: OpenF1Request) throws -> URL {
        var components = URLComponents()
        components.scheme = OpenF1Request.scheme
        components.host = OpenF1Request.host
        components.path = "/v1/\(request.path.rawValue)"
        components.queryItems = try queryItems(from: request.query)
        guard let url = components.url else { throw RequestError.invalidURL }
        return url
    }

    private func urlRequest(for request: OpenF1Request) throws -> URLRequest {
        var result = URLRequest(url: try url(for: request), cachePolicy: .reloadIgnoringLocalCacheData,
                                timeoutInterval: Self.requestTimeout)
        result.httpMethod = request.method.rawValue
        request.headers.forEach { result.setValue($0.value, forHTTPHeaderField: $0.key) }
        if let body = request.body {
            result.httpBody = try JSONEncoder().encode(body)
            result.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return result
    }

    /// CodingKeys를 보존하고 문자열·정수를 쿼리로 변환한다. nil은 생략한다.
    private func queryItems(from query: (any Encodable & Sendable)?) throws -> [URLQueryItem]? {
        guard let query else { return nil }
        let data = try JSONEncoder().encode(query)
        let values: [String: QueryValue]
        do {
            values = try JSONDecoder().decode([String: QueryValue].self, from: data)
        } catch {
            throw RequestError.unsupportedQuery
        }
        let items = values.keys.sorted().compactMap { key -> URLQueryItem? in
            guard let value = values[key]?.text else { return nil }
            return URLQueryItem(name: key, value: value)
        }
        return items.isEmpty ? nil : items
    }

    private enum QueryValue: Decodable {
        case string(String)
        case integer(Int)
        case null

        init(from decoder: any Decoder) throws {
            let value = try decoder.singleValueContainer()
            if value.decodeNil() { self = .null }
            else if let text = try? value.decode(String.self) { self = .string(text) }
            else { self = .integer(try value.decode(Int.self)) }
        }

        var text: String? {
            switch self {
            case let .string(value): value
            case let .integer(value): String(value)
            case .null: nil
            }
        }
    }
}
