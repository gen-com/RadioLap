//
//  DemoRaceListProviderTests.swift
//  RadioLapTests
//

import Foundation
import Testing

@Suite(.serialized)
@MainActor
final class DemoRaceListProviderTests {
    private let repository: any RaceListRepository
    private let repositoryWithoutRelatedMeeting: any RaceListRepository
    private let repositories: [ContractFixture: any RaceListRepository]

    init() throws {
        let bundle = Bundle(for: Self.self)
        let meetingsURL = try #require(bundle.url(
            forResource: "valid-meetings", withExtension: "json", subdirectory: "Fixtures"
        ))
        let sessionsURL = try #require(bundle.url(
            forResource: "valid-sessions", withExtension: "json", subdirectory: "Fixtures"
        ))
        let emptyMeetingsURL = try #require(bundle.url(
            forResource: "empty-meetings", withExtension: "json", subdirectory: "Fixtures"
        ))
        repository = DemoRaceListProvider(meetingsURL: meetingsURL, sessionsURL: sessionsURL)
        repositoryWithoutRelatedMeeting = DemoRaceListProvider(
            meetingsURL: emptyMeetingsURL, sessionsURL: sessionsURL
        )
        var repositories: [ContractFixture: any RaceListRepository] = [:]
        for fixture in ContractFixture.allCases {
            let subdirectory = "Fixtures/\(fixture.rawValue)"
            let meetings = try #require(bundle.url(
                forResource: "meetings", withExtension: "json", subdirectory: subdirectory
            ))
            let sessions = try #require(bundle.url(
                forResource: "sessions", withExtension: "json", subdirectory: subdirectory
            ))
            repositories[fixture] = DemoRaceListProvider(meetingsURL: meetings, sessionsURL: sessions)
        }
        self.repositories = repositories
    }

    // 테스트 결승 종료(2026-01-01 02:00 UTC)보다 한 시간 뒤.
    private let endedBefore = Date(timeIntervalSince1970: 1_767_236_400)

    @Test("조건에 맞는 결승의 식별자·이름·시작 시각·장소를 반환한다")
    func returnsExpectedRace() async throws {
        // Arrange
        let expectedRace = Race(
            sessionID: 1, name: "Test GP",
            startsAt: Date(timeIntervalSince1970: 1_767_225_600), location: "Test Circuit"
        )

        // Act
        let races = try await repository.fetchRaces(year: 2026, endedBefore: endedBefore)

        // Assert
        #expect(races == [expectedRace])
    }

    @Test("요청한 시즌에 결승이 없으면 정상 빈 결과를 반환한다")
    func returnsEmptyForAnotherSeason() async throws {
        // Arrange
        let requestedYear = 2025

        // Act
        let races = try await repository.fetchRaces(year: requestedYear, endedBefore: endedBefore)

        // Assert
        #expect(races.isEmpty)
    }

    @Test("세션에 연결할 대회가 없으면 빈 결과 대신 오류를 전달한다")
    func missingRelatedMeeting() async {
        // Arrange
        let repository = repositoryWithoutRelatedMeeting

        // Act / Assert: 일반 실패의 구체적인 오류 타입은 계약에 포함되지 않는다.
        await #expect {
            try await repository.fetchRaces(year: 2026, endedBefore: endedBefore)
        } throws: { error in
            !(error is CancellationError)
        }
    }

    @Test("조회 전에 취소된 작업에는 CancellationError를 전달한다")
    func cancellationBeforeFetch() async {
        // Arrange
        let before = endedBefore

        // Act
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await self.repository.fetchRaces(year: 2026, endedBefore: before)
        }

        // Assert
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @Test("종료 시각보다 늦은 기준에서만 결승을 포함한다", arguments: [-1, 0, 1])
    func endBoundary(_ secondsAfterEnd: Int) async throws {
        // Arrange: 결승은 2026-01-01 02:00 UTC에 종료한다.
        let raceEnd = Date(timeIntervalSince1970: 1_767_232_800)
        let cutoff = raceEnd.addingTimeInterval(Double(secondsAfterEnd))
        let expectedIDs = secondsAfterEnd > 0 ? [1] : []

        // Act
        let races = try await repository.fetchRaces(year: 2026, endedBefore: cutoff)

        // Assert
        #expect(races.map(\.sessionID) == expectedIDs)
    }

    @Test("같은 Repository도 전달받은 기준 시각에 따라 종료 여부를 다시 판단한다")
    func usesSuppliedCutoff() async throws {
        // Arrange
        let raceEnd = Date(timeIntervalSince1970: 1_767_232_800)

        // Act
        let atEnd = try await repository.fetchRaces(year: 2026, endedBefore: raceEnd)
        let afterEnd = try await repository.fetchRaces(year: 2026, endedBefore: raceEnd.addingTimeInterval(1))

        // Assert
        #expect(atEnd.isEmpty)
        #expect(afterEnd.map(\.sessionID) == [1])
    }

    @Test("시즌·세션 종류·대회 및 세션 취소 조건으로 결승을 선별한다", arguments: [2026, 2025])
    func selectsEligibleRaces(_ year: Int) async throws {
        // Arrange
        let repository = try #require(repositories[.selection])
        let expectedIDs = year == 2026 ? [1] : [7]

        // Act
        let races = try await repository.fetchRaces(year: year, endedBefore: endedBefore)

        // Assert
        #expect(races.map(\.sessionID) == expectedIDs)
    }

    @Test("대회와 세션이 모두 비어 있으면 정상 빈 결과를 반환한다")
    func returnsEmptyForEmptyData() async throws {
        // Arrange
        let repository = try #require(repositories[.empty])

        // Act
        let races = try await repository.fetchRaces(year: 2026, endedBefore: endedBefore)

        // Assert
        #expect(races.isEmpty)
    }

    @Test("장소 누락·null·빈 문자열이어도 레이스를 유지하고 nil로 반환한다")
    func preservesRacesWithoutLocation() async throws {
        // Arrange
        let repository = try #require(repositories[.locations])
        let expected = (1...4).map { id in
            Race(sessionID: id, name: "Test GP",
                 startsAt: Date(timeIntervalSince1970: 1_767_225_600),
                 location: id == 4 ? "Test Circuit" : nil)
        }

        // Act
        let races = try await repository.fetchRaces(year: 2026, endedBefore: endedBefore)

        // Assert: 순서는 계약에 없으므로 식별자로 정렬해 값과 개수를 함께 비교한다.
        #expect(races.sorted { $0.sessionID < $1.sessionID } == expected)
    }

    @Test("배열 순서나 이름 대신 대회 키로 연결하고 결승 시작 시각을 반환한다",
          arguments: [ContractFixture.links, .reorderedLinks])
    private func joinsByMeetingKey(_ fixture: ContractFixture) async throws {
        // Arrange
        let repository = try #require(repositories[fixture])
        let expected = (1...3).map { id in
            Race(sessionID: id, name: id == 1 ? "First GP" : "Same GP",
                 startsAt: Date(timeIntervalSince1970: 1_767_225_600), location: "Test Circuit")
        }

        // Act
        let races = try await repository.fetchRaces(year: 2026, endedBefore: endedBefore)

        // Assert
        #expect(races.sorted { $0.sessionID < $1.sessionID } == expected)
    }

    @Test("동일한 중복은 합치되 다른 식별자의 레이스는 유지한다")
    func removesIdenticalDuplicates() async throws {
        // Arrange
        let repository = try #require(repositories[.duplicates])
        let expected = (1...2).map { id in
            Race(sessionID: id, name: "Test GP",
                 startsAt: Date(timeIntervalSince1970: 1_767_225_600), location: "Test Circuit")
        }

        // Act
        let races = try await repository.fetchRaces(year: 2026, endedBefore: endedBefore)

        // Assert
        #expect(races.sorted { $0.sessionID < $1.sessionID } == expected)
    }

    @Test("중복의 내용이나 표시 여부가 충돌하면 입력 순서와 무관하게 오류를 전달한다",
          arguments: [ContractFixture.sessionContentConflict, .sessionContentConflictReversed,
                      .sessionEligibilityConflict, .sessionEligibilityConflictReversed,
                      .meetingContentConflict, .meetingContentConflictReversed,
                      .meetingEligibilityConflict, .meetingEligibilityConflictReversed])
    private func rejectsConflictingDuplicates(_ fixture: ContractFixture) async throws {
        // Arrange
        let repository = try #require(repositories[fixture])

        // Act / Assert: 일반 실패의 구체적인 오류 타입은 계약에 포함되지 않는다.
        await #expect {
            try await repository.fetchRaces(year: 2026, endedBefore: endedBefore)
        } throws: { error in
            !(error is CancellationError)
        }
    }

    @Test("서로 다른 시차 표기를 같은 절대 시각으로 해석하고 종료 경계에 적용한다",
          arguments: [0, 1])
    func preservesAbsoluteTimes(_ secondsAfterEnd: Int) async throws {
        // Arrange
        let repository = try #require(repositories[.timeOffsets])
        let cutoff = Date(timeIntervalSince1970: 1_767_232_800 + Double(secondsAfterEnd))
        let expected: [Race] = secondsAfterEnd == 0 ? [] : (1...3).map { id in
            Race(sessionID: id, name: "Test GP",
                 startsAt: Date(timeIntervalSince1970: 1_767_225_600), location: "Test Circuit")
        }

        // Act
        let races = try await repository.fetchRaces(year: 2026, endedBefore: cutoff)

        // Assert
        #expect(races.sorted { $0.sessionID < $1.sessionID } == expected)
    }

    @Test("기기 시간대의 날짜·연도가 달라도 반환 대상과 절대 시각은 유지한다",
          arguments: ["UTC", "Asia/Seoul", "America/Los_Angeles"])
    func deviceTimeZoneDoesNotChangeResults(_ identifier: String) async throws {
        // Arrange: 기본 시간대 변경이 같은 suite의 다른 테스트와 겹치지 않도록 직렬 실행한다.
        let repository = try #require(repositories[.timeOffsets])
        let original = NSTimeZone.default
        defer { NSTimeZone.default = original }
        NSTimeZone.default = try #require(TimeZone(identifier: identifier))
        let expected = (1...3).map { id in
            Race(sessionID: id, name: "Test GP",
                 startsAt: Date(timeIntervalSince1970: 1_767_225_600), location: "Test Circuit")
        }
        let raceEnd = Date(timeIntervalSince1970: 1_767_232_800)

        // Act
        let atEnd = try await repository.fetchRaces(year: 2026, endedBefore: raceEnd)
        let afterEnd = try await repository.fetchRaces(year: 2026, endedBefore: endedBefore)

        // Assert
        #expect(atEnd.isEmpty)
        #expect(afterEnd.sorted { $0.sessionID < $1.sessionID } == expected)
    }

}

private enum ContractFixture: String, CaseIterable, Sendable {
    case selection, locations, links, reorderedLinks, duplicates, empty, timeOffsets
    case sessionContentConflict, sessionContentConflictReversed
    case sessionEligibilityConflict, sessionEligibilityConflictReversed
    case meetingContentConflict, meetingContentConflictReversed
    case meetingEligibilityConflict, meetingEligibilityConflictReversed
}
