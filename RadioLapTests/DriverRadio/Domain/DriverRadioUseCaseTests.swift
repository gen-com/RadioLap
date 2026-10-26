//
//  DriverRadioUseCaseTests.swift
//  RadioLapTests
//

import Foundation
import Testing

@MainActor
final class DriverRadioUseCaseTests {

    // MARK: - 테스트: 라디오 조회와 취소

    @Test("라디오 조회는 요청 식별자를 전달하고 해당 자료만 조회하며 정상 빈 결과도 유지한다",
          arguments: [0, 11388], [false, true])
    func fetchesRadioRecords(_ session: Int, _ empty: Bool) async throws {
        // Arrange
        let input: [RadioRecord] = empty ? [] : [try radio()]
        let repository = DriverRadioRepositoryStub(loadRadioRecords: { sessionID, driverNumber in
            #expect(sessionID == session)
            #expect(driverNumber == 44)
            return input
        })
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: repository)

        // Act
        let actual = try await useCase.fetchRadioRecords(sessionID: session, driverNumber: 44)

        // Assert
        #expect(actual == input)
    }

    @Test("라디오 Repository 실패·취소를 빈 성공으로 바꾸지 않는다", arguments: [false, true])
    func forwardsRadioRecordsError(_ cancellation: Bool) async {
        // Arrange
        let repository = DriverRadioRepositoryStub(loadRadioRecords: { _, _ in
            if cancellation { throw CancellationError() }
            throw URLError(.notConnectedToInternet)
        })
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: repository)

        // Act / Assert
        await #expect { try await useCase.fetchRadioRecords(sessionID: 11388, driverNumber: 3) }
        throws: { ($0 is CancellationError) == cancellation }
    }

    @Test("라디오 조회 전에 취소되면 공급자를 호출하지 않는다")
    func cancelsRadioRecordsBeforeFetch() async {
        // Arrange: 기본 대역은 호출되면 실패를 기록한다.
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: DriverRadioRepositoryStub())
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await useCase.fetchRadioRecords(sessionID: 11388, driverNumber: 3)
        }

        // Act / Assert
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test("라디오 조회 중 호출자 취소가 전달되며 늦은 성공·실패보다 취소를 우선한다", arguments: [false, true])
    func cancelsRadioRecordsDuringFetch(_ fail: Bool) async throws {
        // Arrange: 시간 지연 대신 조회 진입과 반환을 직접 제어한다.
        let input: [RadioRecord] = [try radio()]
        let started = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        let repository = DriverRadioRepositoryStub(loadRadioRecords: { _, _ in
            started.continuation.yield(())
            started.continuation.finish()
            for await _ in release.stream { break }
            #expect(Task.isCancelled)
            if fail { throw URLError(.notConnectedToInternet) }
            return input
        })
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: repository)
        let task = Task {
            defer { started.continuation.finish() }
            return try await useCase.fetchRadioRecords(sessionID: 11388, driverNumber: 3)
        }
        defer {
            task.cancel()
            release.continuation.finish()
        }

        // Act
        var events = started.stream.makeAsyncIterator()
        let didStart = await events.next() != nil
        task.cancel()
        release.continuation.yield(())
        release.continuation.finish()

        // Assert
        #expect(didStart)
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    // MARK: - 테스트: 랩 조회와 취소

    @Test("랩 조회는 요청 식별자를 전달하고 해당 자료만 조회하며 정상 빈 결과도 유지한다",
          arguments: [0, 11388], [false, true])
    func fetchesLaps(_ session: Int, _ empty: Bool) async throws {
        // Arrange
        let input: [DriverLap] = empty ? [] : [DriverLap(number: 14, startsAt: time(0), duration: 90)]
        let repository = DriverRadioRepositoryStub(loadLaps: { sessionID, driverNumber in
            #expect(sessionID == session)
            #expect(driverNumber == 44)
            return input
        })
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: repository)

        // Act
        let actual = try await useCase.fetchLaps(sessionID: session, driverNumber: 44)

        // Assert
        #expect(actual == input)
    }

    @Test("랩 Repository 실패·취소를 빈 성공으로 바꾸지 않는다", arguments: [false, true])
    func forwardsLapsError(_ cancellation: Bool) async {
        // Arrange
        let repository = DriverRadioRepositoryStub(loadLaps: { _, _ in
            if cancellation { throw CancellationError() }
            throw URLError(.notConnectedToInternet)
        })
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: repository)

        // Act / Assert
        await #expect { try await useCase.fetchLaps(sessionID: 11388, driverNumber: 3) }
        throws: { ($0 is CancellationError) == cancellation }
    }

    @Test("랩 조회 전에 취소되면 공급자를 호출하지 않는다")
    func cancelsLapsBeforeFetch() async {
        // Arrange: 기본 대역은 호출되면 실패를 기록한다.
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: DriverRadioRepositoryStub())
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await useCase.fetchLaps(sessionID: 11388, driverNumber: 3)
        }

        // Act / Assert
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test("랩 조회 중 호출자 취소가 전달되며 늦은 성공·실패보다 취소를 우선한다", arguments: [false, true])
    func cancelsLapsDuringFetch(_ fail: Bool) async throws {
        // Arrange: 시간 지연 대신 조회 진입과 반환을 직접 제어한다.
        let input: [DriverLap] = [DriverLap(number: 14, startsAt: time(0), duration: 90)]
        let started = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        let repository = DriverRadioRepositoryStub(loadLaps: { _, _ in
            started.continuation.yield(())
            started.continuation.finish()
            for await _ in release.stream { break }
            #expect(Task.isCancelled)
            if fail { throw URLError(.notConnectedToInternet) }
            return input
        })
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: repository)
        let task = Task {
            defer { started.continuation.finish() }
            return try await useCase.fetchLaps(sessionID: 11388, driverNumber: 3)
        }
        defer {
            task.cancel()
            release.continuation.finish()
        }

        // Act
        var events = started.stream.makeAsyncIterator()
        let didStart = await events.next() != nil
        task.cancel()
        release.continuation.yield(())
        release.continuation.finish()

        // Assert
        #expect(didStart)
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    // MARK: - 테스트: 순위 조회와 취소

    @Test("순위 조회는 요청 식별자를 전달하고 해당 자료만 조회하며 정상 빈 결과도 유지한다",
          arguments: [0, 11388], [false, true])
    func fetchesPositions(_ session: Int, _ empty: Bool) async throws {
        // Arrange
        let input: [DriverPosition] = empty ? [] : [DriverPosition(recordedAt: time(0), position: 2)]
        let repository = DriverRadioRepositoryStub(loadPositions: { sessionID, driverNumber in
            #expect(sessionID == session)
            #expect(driverNumber == 44)
            return input
        })
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: repository)

        // Act
        let actual = try await useCase.fetchPositions(sessionID: session, driverNumber: 44)

        // Assert
        #expect(actual == input)
    }

    @Test("순위 Repository 실패·취소를 빈 성공으로 바꾸지 않는다", arguments: [false, true])
    func forwardsPositionsError(_ cancellation: Bool) async {
        // Arrange
        let repository = DriverRadioRepositoryStub(loadPositions: { _, _ in
            if cancellation { throw CancellationError() }
            throw URLError(.notConnectedToInternet)
        })
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: repository)

        // Act / Assert
        await #expect { try await useCase.fetchPositions(sessionID: 11388, driverNumber: 3) }
        throws: { ($0 is CancellationError) == cancellation }
    }

    @Test("순위 조회 전에 취소되면 공급자를 호출하지 않는다")
    func cancelsPositionsBeforeFetch() async {
        // Arrange: 기본 대역은 호출되면 실패를 기록한다.
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: DriverRadioRepositoryStub())
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await useCase.fetchPositions(sessionID: 11388, driverNumber: 3)
        }

        // Act / Assert
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test("순위 조회 중 호출자 취소가 전달되며 늦은 성공·실패보다 취소를 우선한다", arguments: [false, true])
    func cancelsPositionsDuringFetch(_ fail: Bool) async throws {
        // Arrange: 시간 지연 대신 조회 진입과 반환을 직접 제어한다.
        let input: [DriverPosition] = [DriverPosition(recordedAt: time(0), position: 2)]
        let started = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        let repository = DriverRadioRepositoryStub(loadPositions: { _, _ in
            started.continuation.yield(())
            started.continuation.finish()
            for await _ in release.stream { break }
            #expect(Task.isCancelled)
            if fail { throw URLError(.notConnectedToInternet) }
            return input
        })
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: repository)
        let task = Task {
            defer { started.continuation.finish() }
            return try await useCase.fetchPositions(sessionID: 11388, driverNumber: 3)
        }
        defer {
            task.cancel()
            release.continuation.finish()
        }

        // Act
        var events = started.stream.makeAsyncIterator()
        let didStart = await events.next() != nil
        task.cancel()
        release.continuation.yield(())
        release.continuation.finish()

        // Assert
        #expect(didStart)
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    // MARK: - 테스트: 스틴트 조회와 취소

    @Test("스틴트 조회는 요청 식별자를 전달하고 해당 자료만 조회하며 정상 빈 결과도 유지한다",
          arguments: [0, 11388], [false, true])
    func fetchesStints(_ session: Int, _ empty: Bool) async throws {
        // Arrange
        let input: [DriverStint] = empty ? [] : [DriverStint(startLap: 1, endLap: 20, compound: "SOFT")]
        let repository = DriverRadioRepositoryStub(loadStints: { sessionID, driverNumber in
            #expect(sessionID == session)
            #expect(driverNumber == 44)
            return input
        })
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: repository)

        // Act
        let actual = try await useCase.fetchStints(sessionID: session, driverNumber: 44)

        // Assert
        #expect(actual == input)
    }

    @Test("스틴트 Repository 실패·취소를 빈 성공으로 바꾸지 않는다", arguments: [false, true])
    func forwardsStintsError(_ cancellation: Bool) async {
        // Arrange
        let repository = DriverRadioRepositoryStub(loadStints: { _, _ in
            if cancellation { throw CancellationError() }
            throw URLError(.notConnectedToInternet)
        })
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: repository)

        // Act / Assert
        await #expect { try await useCase.fetchStints(sessionID: 11388, driverNumber: 3) }
        throws: { ($0 is CancellationError) == cancellation }
    }

    @Test("스틴트 조회 전에 취소되면 공급자를 호출하지 않는다")
    func cancelsStintsBeforeFetch() async {
        // Arrange: 기본 대역은 호출되면 실패를 기록한다.
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: DriverRadioRepositoryStub())
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await useCase.fetchStints(sessionID: 11388, driverNumber: 3)
        }

        // Act / Assert
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test("스틴트 조회 중 호출자 취소가 전달되며 늦은 성공·실패보다 취소를 우선한다", arguments: [false, true])
    func cancelsStintsDuringFetch(_ fail: Bool) async throws {
        // Arrange: 시간 지연 대신 조회 진입과 반환을 직접 제어한다.
        let input: [DriverStint] = [DriverStint(startLap: 1, endLap: 20, compound: "SOFT")]
        let started = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        let repository = DriverRadioRepositoryStub(loadStints: { _, _ in
            started.continuation.yield(())
            started.continuation.finish()
            for await _ in release.stream { break }
            #expect(Task.isCancelled)
            if fail { throw URLError(.notConnectedToInternet) }
            return input
        })
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: repository)
        let task = Task {
            defer { started.continuation.finish() }
            return try await useCase.fetchStints(sessionID: 11388, driverNumber: 3)
        }
        defer {
            task.cancel()
            release.continuation.finish()
        }

        // Act
        var events = started.stream.makeAsyncIterator()
        let didStart = await events.next() != nil
        task.cancel()
        release.continuation.yield(())
        release.continuation.finish()

        // Assert
        #expect(didStart)
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    // MARK: - 테스트: 자료 정리

    @Test("라디오는 시각·URL이 모두 같은 중복만 합치고 시각순·동시각 URL 문자열순으로 반환한다",
          arguments: [false, true])
    func normalizesRadioRecords(_ reversed: Bool) async throws {
        // Arrange: 쿼리 차이와 같은 URL의 다른 시각도 독립 교신이다.
        let first = try radio(seconds: 0, path: "clip?take=1")
        let second = try radio(seconds: 0, path: "clip?take=2")
        let third = try radio(seconds: 1, path: "clip?take=1")
        let input = [third, second, first, second, first]
        let repository = DriverRadioRepositoryStub(loadRadioRecords: { _, _ in
            reversed ? Array(input.reversed()) : input
        })
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: repository)

        // Act
        let actual = try await useCase.fetchRadioRecords(sessionID: 11388, driverNumber: 3)

        // Assert
        #expect(actual == [first, second, third])
        #expect(actual.map(\.id) == [first, second, third].map {
            RadioRecordID(recordedAt: $0.recordedAt, recordingURLString: $0.recordingURL.absoluteString)
        })
    }

    @Test("랩의 동일 중복만 합치고 불완전·0 이하 소요 시간도 보존한다")
    func preservesIncompleteLaps() async throws {
        // Arrange
        let expected = [DriverLap(number: 1, startsAt: nil, duration: 90),
                        DriverLap(number: 2, startsAt: time(0), duration: nil),
                        DriverLap(number: 3, startsAt: time(90), duration: 0),
                        DriverLap(number: 4, startsAt: time(180), duration: -1),
                        DriverLap(number: 5, startsAt: time(200), duration: 90)]
        let repository = DriverRadioRepositoryStub(loadLaps: { _, _ in expected + expected })
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: repository)

        // Act
        let actual = try await useCase.fetchLaps(sessionID: 11388, driverNumber: 3)

        // Assert: 반환 순서가 아닌 자료와 중복 개수를 비교한다.
        #expect(actual.sorted { $0.number < $1.number } == expected)
    }

    @Test("같은 랩 번호의 값 충돌은 불완전 구간도 제외·보충하지 않고 전체 실패한다",
          arguments: [false, true])
    func rejectsConflictingLaps(_ reversed: Bool) async {
        // Arrange
        let cases: [[DriverLap]] = [
            [.init(number: 1, startsAt: time(0), duration: 90), .init(number: 1, startsAt: time(1), duration: 90)],
            [.init(number: 1, startsAt: time(0), duration: 90), .init(number: 1, startsAt: time(0), duration: -1)],
            [.init(number: 1, startsAt: nil, duration: 90), .init(number: 1, startsAt: time(0), duration: nil)]
        ]
        for records in cases {
            let input = records + [DriverLap(number: 2, startsAt: time(100), duration: 90)]
            let repository = DriverRadioRepositoryStub(loadLaps: { _, _ in
                reversed ? Array(input.reversed()) : input
            })
            let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: repository)

            // Act / Assert
            await #expect { try await useCase.fetchLaps(sessionID: 11388, driverNumber: 3) }
            throws: { !($0 is CancellationError) }
        }
    }

    @Test("순위는 동일 시각·값 중복만 합치고 다른 시각과 숫자 범위를 보존한다")
    func mergesEquivalentPositions() async throws {
        // Arrange
        let expected = [DriverPosition(recordedAt: time(0), position: 0),
                        DriverPosition(recordedAt: time(10), position: 0),
                        DriverPosition(recordedAt: time(20), position: 99)]
        let repository = DriverRadioRepositoryStub(loadPositions: { _, _ in Array(expected.reversed()) + expected })
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: repository)

        // Act
        let actual = try await useCase.fetchPositions(sessionID: 11388, driverNumber: 3)

        // Assert
        #expect(actual.sorted { $0.recordedAt < $1.recordedAt } == expected)
    }

    @Test("같은 시각에 다른 순위가 있으면 다른 정상 기록도 포함하여 전체 실패한다", arguments: [false, true])
    func rejectsConflictingPositions(_ reversed: Bool) async {
        // Arrange
        let input = [DriverPosition(recordedAt: time(0), position: 1),
                     DriverPosition(recordedAt: time(0), position: 2),
                     DriverPosition(recordedAt: time(10), position: 3)]
        let repository = DriverRadioRepositoryStub(loadPositions: { _, _ in
            reversed ? Array(input.reversed()) : input
        })
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: repository)

        // Act / Assert
        await #expect { try await useCase.fetchPositions(sessionID: 11388, driverNumber: 3) }
        throws: { !($0 is CancellationError) }
    }

    @Test("스틴트는 앞뒤 공백과 동일 중복만 정리하고 불완전·역전·겹침·미지의 컴파운드는 유지한다",
          arguments: [false, true])
    func normalizesStints(_ reversed: Bool) async throws {
        // Arrange
        let expected: [DriverStint] = [
            .init(startLap: 1, endLap: 20, compound: "SOFT"),
            .init(startLap: 1, endLap: 20, compound: "soft"),
            .init(startLap: 1, endLap: 20, compound: nil),
            .init(startLap: nil, endLap: 20, compound: "NEW  TYRE"),
            .init(startLap: 21, endLap: nil, compound: nil),
            .init(startLap: 40, endLap: 21, compound: "HARD")]
        let input = expected + [DriverStint(startLap: 1, endLap: 20, compound: " \tSOFT\n"),
                                DriverStint(startLap: 1, endLap: 20, compound: " \t\n\u{00A0}"),
                                DriverStint(startLap: nil, endLap: 20, compound: " NEW  TYRE ")]
        let repository = DriverRadioRepositoryStub(loadStints: { _, _ in
            reversed ? Array(input.reversed()) : input
        })
        let useCase: any DriverRadioUseCase = DriverRadioInteractor(repository: repository)

        // Act
        let actual = try await useCase.fetchStints(sessionID: 11388, driverNumber: 3)

        // Assert: 같은 값의 중복도 발견하도록 일치하는 항목을 하나씩 제거한다.
        var remaining = actual
        for value in expected {
            let index = try #require(remaining.firstIndex(of: value))
            remaining.remove(at: index)
        }
        #expect(remaining.isEmpty)
    }
}

// MARK: - 공통 준비

private extension DriverRadioUseCaseTests {
    func time(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_800_000_000 + seconds)
    }

    func radio(seconds: TimeInterval = 0, path: String = "clip") throws -> RadioRecord {
        .init(recordedAt: time(seconds), recordingURL: try #require(URL(string: "https://example.com/" + path)))
    }
}
