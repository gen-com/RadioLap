//
//  OpenF1APITests.swift
//  RadioLapTests
//

import Foundation
import Testing

@MainActor
struct OpenF1APITests {
    @Test("요청 시즌의 대회와 결승을 조회하고 연결한다")
    func fetchesRaceList() async throws {
        // Arrange
        let requests = RequestLog()
        let client = OpenF1Client { request in
            await requests.append(request)
            let json = request.url!.lastPathComponent == "meetings"
                ? #"[{"meeting_key":9,"meeting_name":"Test GP","year":2026,"is_cancelled":false}]"#
                : #"[{"meeting_key":9,"session_key":12,"session_name":"Race","year":2026,"is_cancelled":false,"date_start":"2026-01-01T10:00:00Z","date_end":"2026-01-01T12:00:00Z"}]"#
            return response(request, json: json)
        }
        // Act
        let result = try await OpenF1RaceListProvider(client: client).fetchRaceCandidates(year: 2026)
        // Assert
        #expect(result.count == 1)
        #expect(result.first?.sessionID == 12)
        #expect(result.first?.linkedMeetings.first?.name == "Test GP")
        let urls = await requests.urls()
        #expect(urls == ["https://api.openf1.org/v1/meetings?year=2026",
                         "https://api.openf1.org/v1/sessions?session_name=Race&year=2026"])
    }

    @Test("상세는 요청 세션의 참가자와 결과만 조회한다")
    func fetchesDetail() async throws {
        // Arrange
        let requests = RequestLog()
        let client = OpenF1Client { request in
            await requests.append(request)
            let json = request.url!.lastPathComponent == "drivers"
                ? #"[{"session_key":12,"driver_number":3,"full_name":"Driver"}]"#
                : #"[{"session_key":12,"driver_number":3,"position":2,"dnf":false,"dns":false,"dsq":false}]"#
            return response(request, json: json)
        }
        // Act
        let result = try await OpenF1RaceDetailProvider(client: client).fetchRaceDetailCandidate(sessionID: 12)
        // Assert
        #expect(result.drivers.count == 1)
        #expect(result.drivers.first?.results.first?.position == 2)
        #expect(await requests.urls() == ["https://api.openf1.org/v1/drivers?session_key=12",
                                          "https://api.openf1.org/v1/session_result?session_key=12"])
    }

    @Test("네 라디오 자료는 각각 세션과 드라이버로 요청하며 데모 지원 목록에 제한받지 않는다")
    func fetchesIndependentRadioData() async throws {
        // Arrange
        let requests = RequestLog()
        let client = OpenF1Client { request in
            await requests.append(request)
            return response(request, json: "[]")
        }
        let repository = OpenF1DriverRadioProvider(client: client)
        // Act
        let radio = try await repository.fetchRadioRecords(sessionID: 999, driverNumber: 99)
        let laps = try await repository.fetchLaps(sessionID: 999, driverNumber: 99)
        let positions = try await repository.fetchPositions(sessionID: 999, driverNumber: 99)
        let stints = try await repository.fetchStints(sessionID: 999, driverNumber: 99)
        // Assert
        #expect(radio.isEmpty && laps.isEmpty && positions.isEmpty && stints.isEmpty)
        #expect(await requests.urls() == ["team_radio", "laps", "position", "stints"].map {
            "https://api.openf1.org/v1/\($0)?driver_number=99&session_key=999"
        })
    }

    @Test("요청과 다른 세션·드라이버가 있으면 라디오 자료 조회를 실패시킨다", arguments: [(12, 44), (13, 3)])
    func rejectsMismatchedRadioRecords(_ identifiers: (Int, Int)) async {
        // Arrange
        let client = OpenF1Client { request in
            response(request, json: "[{\"session_key\":\(identifiers.0),\"driver_number\":\(identifiers.1),\"date\":\"2026-01-01T10:00:00Z\",\"position\":1}]")
        }
        // Act / Assert
        await #expect(throws: (any Error).self) {
            try await OpenF1DriverRadioProvider(client: client).fetchPositions(sessionID: 12, driverNumber: 3)
        }
    }

    @Test("한 자료의 HTTP 실패는 다른 종류의 정상 조회를 막지 않는다")
    func preservesIndependentSuccess() async throws {
        // Arrange
        let repository = OpenF1DriverRadioProvider(client: OpenF1Client { request in
            response(request, status: request.url!.lastPathComponent == "team_radio" ? 503 : 200, json: "[]")
        })
        // Act / Assert
        await #expect(throws: (any Error).self) { try await repository.fetchRadioRecords(sessionID: 12, driverNumber: 3) }
        #expect(try await repository.fetchLaps(sessionID: 12, driverNumber: 3).isEmpty)
    }

    @Test("HTTP 오류는 정상 빈 응답으로 처리하지 않는다", arguments: [199, 300, 401, 404, 429, 500, 503])
    func rejectsHTTPFailure(_ status: Int) async {
        // Arrange
        let client = OpenF1Client { response($0, status: status, json: "[]") }
        // Act / Assert
        await #expect(throws: OpenF1Client.RequestError.httpStatus(status)) {
            try await client.request(OpenF1Request(path: .meetings))
        }
    }

    @Test("2xx 응답은 본문을 그대로 반환한다", arguments: [200, 201, 204, 299])
    func acceptsHTTPSuccess(_ status: Int) async throws {
        // Arrange
        let body = status == 204 ? "" : "response"
        let client = OpenF1Client { response($0, status: status, json: body) }
        // Act
        let data = try await client.request(OpenF1Request(path: .meetings))
        // Assert
        #expect(data == Data(body.utf8))
    }

    @Test("HTTP가 아닌 응답은 성공으로 처리하지 않는다")
    func rejectsNonHTTPResponse() async {
        // Arrange
        let client = OpenF1Client { request in
            (Data(), URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil))
        }
        // Act / Assert
        await #expect(throws: OpenF1Client.RequestError.nonHTTPResponse) {
            try await client.request(OpenF1Request(path: .meetings))
        }
    }

    @Test("목록의 두 번째 자료가 실패하면 부분 후보를 반환하지 않는다", arguments: [false, true])
    func rejectsFailedSessions(_ malformedJSON: Bool) async {
        // Arrange
        let requests = RequestLog()
        let client = OpenF1Client { request in
            await requests.append(request)
            if request.url!.lastPathComponent == "meetings" {
                return response(request, json: #"[{"meeting_key":9,"meeting_name":"Test GP","year":2026}]"#)
            }
            return response(request, status: malformedJSON ? 200 : 503, json: malformedJSON ? "invalid" : "[]")
        }
        // Act / Assert
        await #expect(throws: (any Error).self) {
            try await OpenF1RaceListProvider(client: client).fetchRaceCandidates(year: 2026)
        }
        #expect(await requests.urls().count == 2)
    }

    @Test("상세의 두 번째 자료가 실패하면 부분 참가자를 반환하지 않는다", arguments: [false, true])
    func rejectsFailedResults(_ malformedJSON: Bool) async {
        // Arrange
        let requests = RequestLog()
        let client = OpenF1Client { request in
            await requests.append(request)
            if request.url!.lastPathComponent == "drivers" {
                return response(request, json: #"[{"session_key":12,"driver_number":3,"full_name":"Driver"}]"#)
            }
            return response(request, status: malformedJSON ? 200 : 503, json: malformedJSON ? "invalid" : "[]")
        }
        // Act / Assert
        await #expect(throws: (any Error).self) {
            try await OpenF1RaceDetailProvider(client: client).fetchRaceDetailCandidate(sessionID: 12)
        }
        #expect(await requests.urls().count == 2)
    }

    @Test("취소 후 전송 대역이 성공하거나 일반 오류를 반환해도 취소를 우선한다", arguments: [false, true])
    func prioritizesCancellationOverLateResult(_ fails: Bool) async throws {
        // Arrange: continuation은 호출 취소에 자동 반응하지 않는다.
        let (started, signal) = AsyncStream<CheckedContinuation<Void, Never>>.makeStream()
        defer { signal.finish() }
        let client = OpenF1Client { request in
            await withCheckedContinuation { signal.yield($0) }
            if fails { throw URLError(.timedOut) }
            return response(request, json: "[]")
        }
        let task = Task { try await client.request(OpenF1Request(path: .meetings)) }
        var iterator = started.makeAsyncIterator()
        let pending = try #require(await iterator.next())
        // Act
        task.cancel()
        pending.resume()
        // Assert
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test("통신 실패와 시간 초과를 전달하고 전송 취소만 CancellationError로 바꾼다",
          arguments: [URLError.Code.notConnectedToInternet, .timedOut, .cancelled])
    func handlesTransportErrors(_ code: URLError.Code) async {
        // Arrange
        let client = OpenF1Client { _ in throw URLError(code) }
        // Act / Assert
        if code == .cancelled {
            await #expect(throws: CancellationError.self) { try await client.request(OpenF1Request(path: .meetings)) }
        } else {
            await #expect(throws: URLError(code)) { try await client.request(OpenF1Request(path: .meetings)) }
        }
    }

    @Test("잘못된 JSON은 실제 Provider에서도 조회 실패다")
    func rejectsMalformedJSON() async {
        // Arrange
        let client = OpenF1Client { response($0, json: "invalid") }
        // Act / Assert
        await #expect(throws: (any Error).self) { try await OpenF1RaceListProvider(client: client).fetchRaceCandidates(year: 2026) }
        await #expect(throws: (any Error).self) { try await OpenF1RaceDetailProvider(client: client).fetchRaceDetailCandidate(sessionID: 12) }
        await #expect(throws: (any Error).self) { try await OpenF1DriverRadioProvider(client: client).fetchLaps(sessionID: 12, driverNumber: 3) }
    }

    @Test("진행 중 호출 취소가 전송 작업에 전파된다")
    func cancelsTransport() async throws {
        // Arrange
        let (started, continuation) = AsyncStream<Void>.makeStream()
        let client = OpenF1Client { _ in
            continuation.yield(())
            try await Task.sleep(for: .seconds(60))
            throw URLError(.timedOut)
        }
        let task = Task { try await client.request(OpenF1Request(path: .meetings)) }
        for await _ in started { break }
        // Act
        task.cancel()
        // Assert
        await #expect(throws: CancellationError.self) { try await task.value }
        continuation.finish()
    }

    @Test("데모와 API 구현체는 같은 드라이버 자료를 동일한 Domain 값으로 반환한다")
    func matchesDemoRadioDecoding() async throws {
        // Arrange: 네 자료에서 사용하는 필드를 가진 동일 입력이다.
        let data = Data(#"[{"session_key":12,"driver_number":3,"date":"2026-01-01T10:00:00Z","recording_url":"https://example.com/radio.mp3","lap_number":14,"date_start":null,"lap_duration":90.5,"position":1,"lap_start":1,"lap_end":20,"compound":" SOFT "}]"#.utf8)
        let demo: any DriverRadioRepository = DemoDriverRadioProvider(
            supportedDriversBySession: [12: [3]], loadRadioRecords: { _ in data },
            loadLaps: { _ in data }, loadPositions: { _ in data }, loadStints: { _ in data }
        )
        let api: any DriverRadioRepository = OpenF1DriverRadioProvider(client: OpenF1Client { request in
            (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        // Act
        let demoRadio = try await demo.fetchRadioRecords(sessionID: 12, driverNumber: 3)
        let apiRadio = try await api.fetchRadioRecords(sessionID: 12, driverNumber: 3)
        let demoLaps = try await demo.fetchLaps(sessionID: 12, driverNumber: 3)
        let apiLaps = try await api.fetchLaps(sessionID: 12, driverNumber: 3)
        let demoPositions = try await demo.fetchPositions(sessionID: 12, driverNumber: 3)
        let apiPositions = try await api.fetchPositions(sessionID: 12, driverNumber: 3)
        let demoStints = try await demo.fetchStints(sessionID: 12, driverNumber: 3)
        let apiStints = try await api.fetchStints(sessionID: 12, driverNumber: 3)
        // Assert
        #expect(apiRadio.count == 1 && apiRadio == demoRadio)
        #expect(apiLaps == [DriverLap(number: 14, startsAt: nil, duration: 90.5)])
        #expect(apiLaps == demoLaps)
        #expect(apiPositions.count == 1 && apiPositions.first?.position == 1 && apiPositions == demoPositions)
        #expect(apiStints == [DriverStint(startLap: 1, endLap: 20, compound: " SOFT ")])
        #expect(apiStints == demoStints)
    }

    @Test("GET·요청 시간 제한·캐시 미사용 정책을 전송에 전달한다")
    func configuresRequest() async throws {
        // Arrange
        let client = OpenF1Client { request in
            #expect(request.httpMethod == "GET")
            #expect(request.timeoutInterval == 30)
            #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
            return response(request, json: "[]")
        }
        // Act
        let data = try await client.request(OpenF1Request(path: .meetings))
        // Assert
        #expect(data == Data("[]".utf8))
    }
}

private nonisolated func response(_ request: URLRequest, status: Int = 200, json: String) -> (Data, URLResponse) {
    (Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
}

private actor RequestLog {
    var requests: [URLRequest] = []
    func append(_ request: URLRequest) { requests.append(request) }
    func urls() -> [String] { requests.map { $0.url!.absoluteString } }
}
