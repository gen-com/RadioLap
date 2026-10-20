//
//  RaceListResponseMapperTests.swift
//  RadioLapTests
//

import Foundation
import Testing

@MainActor
final class RaceListResponseMapperTests {
    private let mapper: RaceListResponseMapper
    private let responses: [MapperFixture: (meetings: Data, sessions: Data)]
    // 테스트 결승 종료(2026-01-01 02:00 UTC)보다 한 시간 뒤.
    private let endedBefore = Date(timeIntervalSince1970: 1_767_236_400)

    init() throws {
        let bundle = Bundle(for: Self.self)
        var responses: [MapperFixture: (meetings: Data, sessions: Data)] = [:]
        for fixture in MapperFixture.allCases {
            let subdirectory = "Fixtures/mapper/\(fixture.rawValue)"
            let meetingsURL = try #require(bundle.url(
                forResource: "meetings", withExtension: "json", subdirectory: subdirectory
            ))
            let sessionsURL = try #require(bundle.url(
                forResource: "sessions", withExtension: "json", subdirectory: subdirectory
            ))
            responses[fixture] = (try Data(contentsOf: meetingsURL), try Data(contentsOf: sessionsURL))
        }
        self.responses = responses
        mapper = RaceListResponseMapper()
    }

    @Test("시차와 소수 초를 보존하고 소수 초 단위의 종료 경계를 적용한다", arguments: [0, 1])
    func preservesFractionalTimes(_ millisecondsAfterEnd: Int) throws {
        // Arrange: 세션 1·2는 같은 순간을 다른 시차로 표기하며, 세션 3은 소수 초가 0이다.
        let response = try #require(responses[.fractionalTimes])
        let cutoff = Date(timeIntervalSince1970: 1_767_232_800.125 + Double(millisecondsAfterEnd) / 1000)
        let expectedIDs = millisecondsAfterEnd == 0 ? [3] : [1, 2, 3]
        let expected = expectedIDs.map { id in
            Race(sessionID: id, name: "Test GP",
                 startsAt: Date(timeIntervalSince1970: 1_767_225_600 + (id == 3 ? 0 : 0.125)),
                 location: "Test Circuit")
        }

        // Act
        let races = try mapper.races(meetingsData: response.meetings, sessionsData: response.sessions,
                                     year: 2026, endedBefore: cutoff)

        // Assert
        #expect(races.sorted { $0.sessionID < $1.sessionID } == expected)
    }

    @Test("조회에서 제외된 세션의 연결 누락과 사용하지 않는 대회의 충돌은 결과에 영향을 주지 않는다")
    func ignoresExcludedRelationships() throws {
        // Arrange
        let response = try #require(responses[.excludedRelationships])
        let expected = Race(sessionID: 1, name: "Test GP",
                            startsAt: Date(timeIntervalSince1970: 1_767_225_600), location: "Test Circuit")

        // Act
        let races = try mapper.races(meetingsData: response.meetings, sessionsData: response.sessions,
                                     year: 2026, endedBefore: endedBefore)

        // Assert
        #expect(races == [expected])
    }

    @Test("대회가 모두 취소된 경우 표시하지 않을 중복 내용의 차이는 무시한다")
    func ignoresCancelledMeetingDifferences() throws {
        // Arrange
        let response = try #require(responses[.cancelledMeetingDifferences])

        // Act
        let races = try mapper.races(meetingsData: response.meetings, sessionsData: response.sessions,
                                     year: 2026, endedBefore: endedBefore)

        // Assert
        #expect(races.isEmpty)
    }

    @Test("같은 세션의 연결 대회에 따라 표시 여부가 달라지면 입력 순서와 무관하게 실패한다",
          arguments: [MapperFixture.crossMeetingConflict, .crossMeetingConflictReversed])
    private func rejectsCrossMeetingConflict(_ fixture: MapperFixture) throws {
        // Arrange
        let response = try #require(responses[fixture])

        // Act / Assert
        #expect {
            try mapper.races(meetingsData: response.meetings, sessionsData: response.sessions,
                             year: 2026, endedBefore: endedBefore)
        } throws: { error in
            !(error is CancellationError)
        }
    }

    @Test("표시할 대회의 시즌·이름과 결승의 시각 관계가 유효하지 않으면 실패한다",
          arguments: [MapperFixture.meetingSeasonMismatch, .emptyMeetingName, .reversedSessionTime])
    private func rejectsInvalidVisibleValues(_ fixture: MapperFixture) throws {
        // Arrange: JSON 문법·타입은 정상이지만 표시 대상의 값이 유효하지 않은 자료다.
        let response = try #require(responses[fixture])

        // Act / Assert
        #expect {
            try mapper.races(meetingsData: response.meetings, sessionsData: response.sessions,
                             year: 2026, endedBefore: endedBefore)
        } throws: { error in
            !(error is CancellationError)
        }
    }
}

private enum MapperFixture: String, CaseIterable, Sendable {
    case fractionalTimes, excludedRelationships, cancelledMeetingDifferences
    case crossMeetingConflict, crossMeetingConflictReversed
    case meetingSeasonMismatch, emptyMeetingName, reversedSessionTime
}
