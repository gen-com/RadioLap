//
//  DriverRadioRepositoryTests.swift
//  RadioLapTests
//

import Foundation
import Testing

@MainActor
final class DriverRadioRepositoryTests {

    // MARK: - 테스트: 요청과 응답 변환

    @Test("네 자료를 요청 드라이버로 선택하고 각 필드를 변환한다")
    func mapsRequestedRecords() async throws {
        // Arrange
        let repository = try repository()
        let date = Date(timeIntervalSince1970: 1_791_720_000.125)
        let url = try #require(URL(string: "https://example.com/radio.mp3?clip=1"))

        // Act
        let radio = try await repository.fetchRadioRecords(sessionID: 11388, driverNumber: 3)
        let laps = try await repository.fetchLaps(sessionID: 11388, driverNumber: 3)
        let positions = try await repository.fetchPositions(sessionID: 11388, driverNumber: 3)
        let stints = try await repository.fetchStints(sessionID: 11388, driverNumber: 3)

        // Assert
        #expect(radio == [RadioRecord(recordedAt: date, recordingURL: url)])
        #expect(laps == [DriverLap(number: 14, startsAt: date, duration: 90.5)])
        #expect(positions == [DriverPosition(recordedAt: date, position: 1)])
        #expect(stints == [DriverStint(startLap: 1, endLap: 20, compound: " SOFT ")])
    }

    @Test("요청 세션을 자료 공급에 전달하고 해당 세션·드라이버의 값을 반환한다", arguments: [11388, 2])
    func forwardsRequestedSession(_ sessionID: Int) async throws {
        // Arrange: 테스트용 지원 세션이며 실제 데모의 지원 범위를 변경하지 않는다.
        let secondSession = try response("response-second-session")
        let radio = [11388: try response("team_radio-normal"), 2: secondSession]
        let laps = [11388: try response("laps-normal"), 2: secondSession]
        let positions = [11388: try response("position-normal"), 2: secondSession]
        let stints = [11388: try response("stints-normal"), 2: secondSession]
        let repository: any DriverRadioRepository = DemoDriverRadioProvider(
            supportedDriversBySession: [11388: [1, 3, 44], 2: [44]],
            loadRadioRecords: { requested in
                #expect(requested == sessionID)
                return try #require(radio[requested])
            },
            loadLaps: { requested in
                #expect(requested == sessionID)
                return try #require(laps[requested])
            },
            loadPositions: { requested in
                #expect(requested == sessionID)
                return try #require(positions[requested])
            },
            loadStints: { requested in
                #expect(requested == sessionID)
                return try #require(stints[requested])
            }
        )
        let expectedDate = Date(timeIntervalSince1970: 1_791_720_000.125)
        let expectedURL = try #require(URL(string: sessionID == 11388
            ? "https://example.com/driver-44.mp3" : "https://example.com/second-session.mp3"))
        let expectedLaps = sessionID == 11388
            ? [DriverLap(number: 27, startsAt: expectedDate, duration: 99)]
            : [DriverLap(number: 7, startsAt: expectedDate, duration: 88)]
        let expectedPositions = [DriverPosition(recordedAt: expectedDate, position: sessionID == 11388 ? 5 : 2)]
        let expectedStints = sessionID == 11388
            ? [DriverStint(startLap: 21, endLap: 40, compound: "MEDIUM")]
            : [DriverStint(startLap: 1, endLap: 10, compound: "HARD")]

        // Act
        let records = try await repository.fetchRadioRecords(sessionID: sessionID, driverNumber: 44)
        let driverLaps = try await repository.fetchLaps(sessionID: sessionID, driverNumber: 44)
        let driverPositions = try await repository.fetchPositions(sessionID: sessionID, driverNumber: 44)
        let driverStints = try await repository.fetchStints(sessionID: sessionID, driverNumber: 44)

        // Assert
        #expect(records == [RadioRecord(recordedAt: expectedDate, recordingURL: expectedURL)])
        #expect(driverLaps == expectedLaps)
        #expect(driverPositions == expectedPositions)
        #expect(driverStints == expectedStints)
    }

    @Test("지원 드라이버의 기록 부재는 네 조회 모두 정상 빈 결과이다")
    func returnsEmptyForSupportedDriver() async throws {
        // Arrange
        let repository = try repository()

        // Act
        let radio = try await repository.fetchRadioRecords(sessionID: 11388, driverNumber: 1)
        let laps = try await repository.fetchLaps(sessionID: 11388, driverNumber: 1)
        let positions = try await repository.fetchPositions(sessionID: 11388, driverNumber: 1)
        let stints = try await repository.fetchStints(sessionID: 11388, driverNumber: 1)

        // Assert
        #expect(radio.isEmpty)
        #expect(laps.isEmpty)
        #expect(positions.isEmpty)
        #expect(stints.isEmpty)
    }

    @Test("빈 응답은 정상 빈 결과로 반환한다")
    func returnsEmptyResponses() async throws {
        // Arrange
        let repository = try repository(radio: "response-empty", laps: "response-empty",
                                        positions: "response-empty", stints: "response-empty")

        // Act
        let radio = try await repository.fetchRadioRecords(sessionID: 11388, driverNumber: 3)
        let laps = try await repository.fetchLaps(sessionID: 11388, driverNumber: 3)
        let positions = try await repository.fetchPositions(sessionID: 11388, driverNumber: 3)
        let stints = try await repository.fetchStints(sessionID: 11388, driverNumber: 3)

        // Assert
        #expect(radio.isEmpty)
        #expect(laps.isEmpty)
        #expect(positions.isEmpty)
        #expect(stints.isEmpty)
    }

    @Test("미지원 세션·드라이버 요청은 기록 부재와 구분한다", arguments: [(1, 3), (11388, 999)])
    func rejectsUnsupportedRequest(_ request: (Int, Int)) async throws {
        // Arrange
        let repository = try repository()

        // Act / Assert
        await #expect { try await repository.fetchRadioRecords(sessionID: request.0, driverNumber: request.1) }
        throws: { !($0 is CancellationError) }
        await #expect { try await repository.fetchLaps(sessionID: request.0, driverNumber: request.1) }
        throws: { !($0 is CancellationError) }
        await #expect { try await repository.fetchPositions(sessionID: request.0, driverNumber: request.1) }
        throws: { !($0 is CancellationError) }
        await #expect { try await repository.fetchStints(sessionID: request.0, driverNumber: request.1) }
        throws: { !($0 is CancellationError) }
    }

    // MARK: - 테스트: 응답 해석과 오류

    @Test("응답 구조·식별자·세션 오류는 각 조회의 실패로 전달한다", arguments: [
        "response-malformed", "response-object", "response-null-element",
        "foreign-session", "missing-driver", "invalid-driver"
    ])
    func rejectsInvalidResponse(_ sample: String) async throws {
        // Arrange: 다른 세션의 레코드가 선택하지 않은 드라이버여도 응답 전체를 검증해야 한다.
        let repository = try repository(radio: sample, laps: sample, positions: sample, stints: sample)

        // Act / Assert
        await #expect { try await repository.fetchRadioRecords(sessionID: 11388, driverNumber: 3) }
        throws: { !($0 is CancellationError) }
        await #expect { try await repository.fetchLaps(sessionID: 11388, driverNumber: 3) }
        throws: { !($0 is CancellationError) }
        await #expect { try await repository.fetchPositions(sessionID: 11388, driverNumber: 3) }
        throws: { !($0 is CancellationError) }
        await #expect { try await repository.fetchStints(sessionID: 11388, driverNumber: 3) }
        throws: { !($0 is CancellationError) }
    }

    @Test("라디오의 필수 필드·타입 오류와 해석할 수 없는 날짜를 전달한다", arguments: [
        "team_radio-required-missing",
        "team_radio-required-null",
        "team_radio-required-type",
        "team_radio-date-no-offset",
        "team_radio-date-invalid"
    ])
    func rejectsInvalidRadioRecords(_ sample: String) async throws {
        // Arrange
        let repository = try repository(radio: sample)

        // Act / Assert
        await #expect { try await repository.fetchRadioRecords(sessionID: 11388, driverNumber: 3) }
        throws: { !($0 is CancellationError) }
    }

    @Test("랩 번호 오류와 선택 시간 값의 해석 실패를 부재로 숨기지 않는다", arguments: [
        "laps-required-missing",
        "laps-required-null",
        "laps-required-type",
        "laps-invalid-start",
        "laps-invalid-duration"
    ])
    func rejectsInvalidLaps(_ sample: String) async throws {
        // Arrange
        let repository = try repository(laps: sample)

        // Act / Assert
        await #expect { try await repository.fetchLaps(sessionID: 11388, driverNumber: 3) }
        throws: { !($0 is CancellationError) }
    }

    @Test("순위 기록의 필수 값과 정수 해석 오류를 거부한다", arguments: [
        "position-required-missing",
        "position-required-null",
        "position-required-type",
        "position-fraction",
        "position-string",
        "position-overflow"
    ])
    func rejectsInvalidPositions(_ sample: String) async throws {
        // Arrange
        let repository = try repository(positions: sample)

        // Act / Assert
        await #expect { try await repository.fetchPositions(sessionID: 11388, driverNumber: 3) }
        throws: { !($0 is CancellationError) }
    }

    @Test("스틴트 식별자 오류와 선택 범위·컴파운드 오류를 거부한다", arguments: [
        "stints-required-missing",
        "stints-required-null",
        "stints-required-type",
        "stints-invalid-end",
        "stints-invalid-compound"
    ])
    func rejectsInvalidStints(_ sample: String) async throws {
        // Arrange
        let repository = try repository(stints: sample)

        // Act / Assert
        await #expect { try await repository.fetchStints(sessionID: 11388, driverNumber: 3) }
        throws: { !($0 is CancellationError) }
    }

    // MARK: - 테스트: 값과 중복 보존

    @Test("다른 드라이버의 비식별자 필드 오류는 현재 조회에 영향을 주지 않는다")
    func ignoresUnselectedFieldErrors() async throws {
        // Arrange
        let repository = try repository(radio: "team_radio-foreign-invalid-date")

        // Act
        let records = try await repository.fetchRadioRecords(sessionID: 11388, driverNumber: 3)

        // Assert
        let expected = RadioRecord(
            recordedAt: Date(timeIntervalSince1970: 1_791_720_000.125),
            recordingURL: try #require(URL(string: "https://example.com/radio.mp3?clip=1"))
        )
        #expect(records == [expected])
    }

    @Test("선택 값이 누락·null이어도 랩과 스틴트의 다른 제공 값은 보존한다")
    func preservesAbsentValues() async throws {
        // Arrange
        let lapsRepository = try repository(laps: "laps-optional")
        let stintsRepository = try repository(stints: "stints-optional")

        // Act
        let laps = try await lapsRepository.fetchLaps(sessionID: 11388, driverNumber: 3)
        let stints = try await stintsRepository.fetchStints(sessionID: 11388, driverNumber: 3)

        // Assert
        expectSameRecords(laps, [
            DriverLap(number: 1, startsAt: nil, duration: nil),
            DriverLap(number: 2, startsAt: nil, duration: nil),
            DriverLap(number: 3, startsAt: nil, duration: 90.5),
            DriverLap(number: 4, startsAt: Date(timeIntervalSince1970: 1_791_720_000.125), duration: nil)
        ])
        expectSameRecords(stints, [
            DriverStint(startLap: nil, endLap: nil, compound: nil),
            DriverStint(startLap: nil, endLap: nil, compound: nil),
            DriverStint(startLap: 1, endLap: nil, compound: "SOFT"),
            DriverStint(startLap: nil, endLap: 20, compound: "MEDIUM"),
            DriverStint(startLap: 21, endLap: 40, compound: nil)
        ])
    }

    @Test("시차와 소수 초를 해석하되 같은 시각·URL의 중복은 보존한다")
    func decodesOffsetsWithoutDeduplication() async throws {
        // Arrange
        let repository = try repository(radio: "team_radio-offsets")
        let url = try #require(URL(string: "https://example.com/radio.mp3"))
        let date = Date(timeIntervalSince1970: 1_791_720_000)

        // Act
        let records = try await repository.fetchRadioRecords(sessionID: 11388, driverNumber: 3)

        // Assert
        expectSameRecords(records, [RadioRecord(recordedAt: date, recordingURL: url),
                                    RadioRecord(recordedAt: date, recordingURL: url),
                                    RadioRecord(recordedAt: date.addingTimeInterval(0.125), recordingURL: url)])
    }

    @Test("동일·상충 레코드와 구간을 구성할 수 없는 값을 정리하지 않는다")
    func preservesDuplicatesAndIncompleteIntervals() async throws {
        // Arrange
        let repository = try repository(radio: "team_radio-preserved", laps: "laps-preserved",
                                        positions: "position-preserved", stints: "stints-preserved")
        let date = Date(timeIntervalSince1970: 1_791_720_000.125)
        let firstURL = try #require(URL(string: "https://example.com/radio.mp3?clip=1"))
        let otherURL = try #require(URL(string: "http://example.com/other.mp3"))

        // Act
        let radio = try await repository.fetchRadioRecords(sessionID: 11388, driverNumber: 3)
        let laps = try await repository.fetchLaps(sessionID: 11388, driverNumber: 3)
        let positions = try await repository.fetchPositions(sessionID: 11388, driverNumber: 3)
        let stints = try await repository.fetchStints(sessionID: 11388, driverNumber: 3)

        // Assert
        expectSameRecords(radio, [.init(recordedAt: date, recordingURL: firstURL),
                                  .init(recordedAt: date, recordingURL: firstURL),
                                  .init(recordedAt: date, recordingURL: otherURL)])
        expectSameRecords(laps, [.init(number: 14, startsAt: date, duration: 90.5),
                                 .init(number: 14, startsAt: date, duration: 90.5),
                                 .init(number: 14, startsAt: date, duration: -1)])
        expectSameRecords(positions, [.init(recordedAt: date, position: 1),
                                      .init(recordedAt: date, position: 1), .init(recordedAt: date, position: 0)])
        expectSameRecords(stints, [.init(startLap: 1, endLap: 20, compound: " SOFT "),
                                   .init(startLap: 1, endLap: 20, compound: " SOFT "),
                                   .init(startLap: 20, endLap: 1, compound: "")])
    }

    @Test("0초 소요 시간을 보정하지 않고 보존한다")
    func preservesZeroDuration() async throws {
        // Arrange
        let repository = try repository(laps: "laps-zero-duration")

        // Act
        let laps = try await repository.fetchLaps(sessionID: 11388, driverNumber: 3)

        // Assert
        #expect(laps == [DriverLap(number: 14, startsAt: Date(timeIntervalSince1970: 1_791_720_000.125),
                                  duration: 0)])
    }

    // MARK: - 테스트: 공급 독립성과 취소

    @Test("라디오 조회는 다른 자료를 읽지 않고 해당 결과만 반환한다")
    func readsOnlyRadioRecords() async throws {
        // Arrange: 다른 자료의 읽기를 실패시켜 조회 간 의존이 없는지 확인한다.
        let selectedURL = try file("team_radio-normal")
        let repository = try repository(read: { url in
            guard url == selectedURL else { throw CocoaError(.fileReadNoPermission) }
            return try Data(contentsOf: url)
        })
        let date = Date(timeIntervalSince1970: 1_791_720_000.125)
        let expected = [RadioRecord(recordedAt: date, recordingURL: try #require(URL(string: "https://example.com/radio.mp3?clip=1")))]

        // Act
        let actual = try await repository.fetchRadioRecords(sessionID: 11388, driverNumber: 3)

        // Assert
        #expect(actual == expected)
    }

    @Test("랩 조회는 다른 자료를 읽지 않고 해당 결과만 반환한다")
    func readsOnlyLaps() async throws {
        // Arrange: 다른 자료의 읽기를 실패시켜 조회 간 의존이 없는지 확인한다.
        let selectedURL = try file("laps-normal")
        let repository = try repository(read: { url in
            guard url == selectedURL else { throw CocoaError(.fileReadNoPermission) }
            return try Data(contentsOf: url)
        })
        let date = Date(timeIntervalSince1970: 1_791_720_000.125)
        let expected = [DriverLap(number: 14, startsAt: date, duration: 90.5)]

        // Act
        let actual = try await repository.fetchLaps(sessionID: 11388, driverNumber: 3)

        // Assert
        #expect(actual == expected)
    }

    @Test("순위 조회는 다른 자료를 읽지 않고 해당 결과만 반환한다")
    func readsOnlyPositions() async throws {
        // Arrange: 다른 자료의 읽기를 실패시켜 조회 간 의존이 없는지 확인한다.
        let selectedURL = try file("position-normal")
        let repository = try repository(read: { url in
            guard url == selectedURL else { throw CocoaError(.fileReadNoPermission) }
            return try Data(contentsOf: url)
        })
        let date = Date(timeIntervalSince1970: 1_791_720_000.125)
        let expected = [DriverPosition(recordedAt: date, position: 1)]

        // Act
        let actual = try await repository.fetchPositions(sessionID: 11388, driverNumber: 3)

        // Assert
        #expect(actual == expected)
    }

    @Test("스틴트 조회는 다른 자료를 읽지 않고 해당 결과만 반환한다")
    func readsOnlyStints() async throws {
        // Arrange: 다른 자료의 읽기를 실패시켜 조회 간 의존이 없는지 확인한다.
        let selectedURL = try file("stints-normal")
        let repository = try repository(read: { url in
            guard url == selectedURL else { throw CocoaError(.fileReadNoPermission) }
            return try Data(contentsOf: url)
        })
        let expected = [DriverStint(startLap: 1, endLap: 20, compound: " SOFT ")]

        // Act
        let actual = try await repository.fetchStints(sessionID: 11388, driverNumber: 3)

        // Assert
        #expect(actual == expected)
    }

    @Test("공급 실패를 빈 성공으로 바꾸지 않고 공급 취소와 구분한다", arguments: [false, true])
    func forwardsSupplyFailure(_ cancelled: Bool) async throws {
        // Arrange
        let repository = try repository(read: { _ in
            if cancelled { throw CancellationError() }
            throw CocoaError(.fileReadNoSuchFile)
        })

        // Act / Assert
        await #expect { try await repository.fetchRadioRecords(sessionID: 11388, driverNumber: 3) }
        throws: { ($0 is CancellationError) == cancelled }
        await #expect { try await repository.fetchLaps(sessionID: 11388, driverNumber: 3) }
        throws: { ($0 is CancellationError) == cancelled }
        await #expect { try await repository.fetchPositions(sessionID: 11388, driverNumber: 3) }
        throws: { ($0 is CancellationError) == cancelled }
        await #expect { try await repository.fetchStints(sessionID: 11388, driverNumber: 3) }
        throws: { ($0 is CancellationError) == cancelled }
    }

    @Test("이미 취소된 호출은 자료를 읽지 않고 각 조회가 취소를 전달한다")
    func rejectsCancelledCall() async throws {
        // Arrange
        let repository = try repository(read: { _ in
            Issue.record("취소된 호출에서 자료를 읽었습니다")
            throw CocoaError(.fileReadUnknown)
        })
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }

            // Act / Assert
            await #expect(throws: CancellationError.self) {
                try await repository.fetchRadioRecords(sessionID: 11388, driverNumber: 3)
            }
            await #expect(throws: CancellationError.self) {
                try await repository.fetchLaps(sessionID: 11388, driverNumber: 3)
            }
            await #expect(throws: CancellationError.self) {
                try await repository.fetchPositions(sessionID: 11388, driverNumber: 3)
            }
            await #expect(throws: CancellationError.self) {
                try await repository.fetchStints(sessionID: 11388, driverNumber: 3)
            }
        }
        await task.value
    }

    @Test("라디오 공급 중 호출 취소가 관찰되면 성공·일반 오류보다 취소를 우선한다", arguments: [false, true])
    func cancelsRadioRecordsDuringRead(_ fail: Bool) async throws {
        // Arrange: 시간 지연에 의존하지 않고 호출 작업 안에서 취소한다.
        let repository = try repository(read: { url in
            withUnsafeCurrentTask { $0?.cancel() }
            if fail { throw CocoaError(.fileReadUnknown) }
            return try Data(contentsOf: url)
        })
        let task = Task { try await repository.fetchRadioRecords(sessionID: 11388, driverNumber: 3) }

        // Act / Assert
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test("랩 공급 중 호출 취소가 관찰되면 성공·일반 오류보다 취소를 우선한다", arguments: [false, true])
    func cancelsLapsDuringRead(_ fail: Bool) async throws {
        // Arrange: 시간 지연에 의존하지 않고 호출 작업 안에서 취소한다.
        let repository = try repository(read: { url in
            withUnsafeCurrentTask { $0?.cancel() }
            if fail { throw CocoaError(.fileReadUnknown) }
            return try Data(contentsOf: url)
        })
        let task = Task { try await repository.fetchLaps(sessionID: 11388, driverNumber: 3) }

        // Act / Assert
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test("순위 공급 중 호출 취소가 관찰되면 성공·일반 오류보다 취소를 우선한다", arguments: [false, true])
    func cancelsPositionsDuringRead(_ fail: Bool) async throws {
        // Arrange: 시간 지연에 의존하지 않고 호출 작업 안에서 취소한다.
        let repository = try repository(read: { url in
            withUnsafeCurrentTask { $0?.cancel() }
            if fail { throw CocoaError(.fileReadUnknown) }
            return try Data(contentsOf: url)
        })
        let task = Task { try await repository.fetchPositions(sessionID: 11388, driverNumber: 3) }

        // Act / Assert
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test("스틴트 공급 중 호출 취소가 관찰되면 성공·일반 오류보다 취소를 우선한다", arguments: [false, true])
    func cancelsStintsDuringRead(_ fail: Bool) async throws {
        // Arrange: 시간 지연에 의존하지 않고 호출 작업 안에서 취소한다.
        let repository = try repository(read: { url in
            withUnsafeCurrentTask { $0?.cancel() }
            if fail { throw CocoaError(.fileReadUnknown) }
            return try Data(contentsOf: url)
        })
        let task = Task { try await repository.fetchStints(sessionID: 11388, driverNumber: 3) }

        // Act / Assert
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}

// MARK: - 입력 준비와 결과 비교

private extension DriverRadioRepositoryTests {
    // 구체 Provider 생성은 준비 단계에 한정한다. 검증은 Repository 계약으로 호출한다.
    func repository(
        radio: String = "team_radio-normal", laps: String = "laps-normal",
        positions: String = "position-normal", stints: String = "stints-normal",
        read: @escaping @Sendable (URL) async throws -> Data = { try Data(contentsOf: $0) }
    ) throws -> any DriverRadioRepository {
        let radioURL = try file(radio)
        let lapsURL = try file(laps)
        let positionsURL = try file(positions)
        let stintsURL = try file(stints)
        return DemoDriverRadioProvider(
            supportedDriversBySession: [11388: [1, 3, 44]],
            loadRadioRecords: { _ in try await read(radioURL) },
            loadLaps: { _ in try await read(lapsURL) },
            loadPositions: { _ in try await read(positionsURL) },
            loadStints: { _ in try await read(stintsURL) }
        )
    }

    func file(_ name: String) throws -> URL {
        try #require(Bundle(for: Self.self).url(
            forResource: name, withExtension: "json", subdirectory: "DriverRadioFixtures"
        ))
    }

    func response(_ name: String) throws -> Data {
        try Data(contentsOf: file(name))
    }

    func expectSameRecords<Value: Equatable>(_ actual: [Value], _ expected: [Value],
                                             sourceLocation: SourceLocation = #_sourceLocation) {
        // 중복 개수를 보존하고 순서만 무시하기 위해 일치하는 값을 하나씩 제거한다.
        var remaining = actual
        for value in expected {
            guard let index = remaining.firstIndex(of: value) else {
                Issue.record("기대한 레코드가 없습니다: \(value)", sourceLocation: sourceLocation)
                return
            }
            remaining.remove(at: index)
        }
        #expect(remaining.isEmpty, sourceLocation: sourceLocation)
    }
}
