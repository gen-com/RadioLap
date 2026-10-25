//
//  RaceListRepositoryTests.swift
//  RadioLapTests
//

import Foundation
import Testing

@MainActor
final class RaceListRepositoryTests {
    @Test("정상 대회·세션 자료를 후보 한 건으로 반환한다")
    func returnsExpectedCandidate() async throws {
        // Arrange
        let repository = try repository(meetings: "meetings-normal", sessions: "sessions-normal")
        let expected = RaceCandidate(
            sessionID: 101, season: 2026, kind: .race, isCancelled: false,
            // 2026-01-01 00:00:00 UTC와 02:00:00 UTC.
            startsAt: Date(timeIntervalSince1970: 1_767_225_600),
            endsAt: Date(timeIntervalSince1970: 1_767_232_800),
            location: "Test Circuit",
            linkedMeetings: [RaceMeetingCandidate(name: "Test Grand Prix", season: 2026, isCancelled: false)]
        )

        // Act
        let candidates = try await repository.fetchRaceCandidates(year: 2026)

        // Assert
        #expect(candidates == [expected])
    }

    @Test("요청 시즌을 자료 공급에 전달한다", arguments: [2025, 2026])
    func forwardsSeason(year: Int) async throws {
        // Arrange: 호출 횟수나 자료 요청의 내부 순서는 요구하지 않는다.
        let meetings = try response("meetings-normal")
        let sessions = try response("sessions-normal")
        let repository: any RaceListRepository = DemoRaceListProvider { requestedYear in
            #expect(requestedYear == year)
            return (meetings, sessions)
        }

        // Act
        let candidates = try await repository.fetchRaceCandidates(year: year)

        // Assert: 자료를 실제로 공급받아 후보로 반환했는지도 확인한다.
        #expect(candidates == [candidate()])
    }

    @Test("키로 대회를 연결하고 세션·대회의 동일 중복과 충돌 값을 보존한다")
    func preservesLinkedDuplicates() async throws {
        // Arrange: 같은 이름의 다른 대회, 중복·충돌 대회와 세션을 함께 공급한다.
        let repository = try repository(meetings: "meetings-linked", sessions: "sessions-linked")
        let cancelled = [RaceMeetingCandidate(name: "Test Grand Prix", season: 2026, isCancelled: true)]
        let expected = [
            candidate(id: 202, location: "Second Circuit", meetings: [
                RaceMeetingCandidate(name: "Test Grand Prix", season: 2025, isCancelled: false)
            ]),
            candidate(meetings: duplicateMeetings),
            candidate(meetings: duplicateMeetings),
            candidate(meetings: duplicateMeetings),
            candidate(season: 2025, kind: .other, cancelled: true,
                      start: 1_767_312_000, end: 1_767_319_200, location: "Other Circuit", meetings: duplicateMeetings),
            candidate(id: 202, meetings: duplicateMeetings)
        ]

        // Act
        let candidates = try await repository.fetchRaceCandidates(year: 2026)

        // Assert: 공유 자료 20건은 이 테스트와 연결 누락·종류·조회 자격 테스트가 나누어 검증한다.
        #expect(candidates.count == 20)
        let linked = candidates.filter {
            [101, 202].contains($0.sessionID ?? -1)
                && !$0.linkedMeetings.isEmpty && $0.linkedMeetings != cancelled
        }
        expectCandidates(linked, expected)
    }

    @Test("대회 키가 일치하지 않거나 없으면 연결 없는 후보를 보존한다")
    func preservesUnlinkedCandidates() async throws {
        // Arrange
        let repository = try repository(meetings: "meetings-linked", sessions: "sessions-linked")
        let expected = [candidate(meetings: []), candidate(id: 202, meetings: [])]

        // Act
        let candidates = try await repository.fetchRaceCandidates(year: 2026)

        // Assert
        expectCandidates(candidates.filter { $0.linkedMeetings.isEmpty }, expected)
    }

    @Test("결승·알려진 비결승·알 수 없는 종류를 구분하고 후보를 유지한다")
    func preservesSessionKinds() async throws {
        // Arrange: 공유 자료의 식별자 1~9가 종류별 사례다.
        let repository = try repository(meetings: "meetings-linked", sessions: "sessions-linked")
        let expected = [candidate(id: 1, meetings: duplicateMeetings)]
            + (2...8).map { candidate(id: $0, kind: .other, meetings: duplicateMeetings) }
            + [candidate(id: 9, kind: nil, meetings: duplicateMeetings)]

        // Act
        let candidates = try await repository.fetchRaceCandidates(year: 2026)

        // Assert
        expectCandidates(candidates.filter { (1...9).contains($0.sessionID ?? -1) }, expected)
    }

    @Test("다른 시즌·대회 및 세션 취소·미래 시각을 이유로 후보를 선별하지 않는다")
    func preservesSelectionCandidates() async throws {
        // Arrange: 공유 자료에서 대회 30에 연결된 세 후보가 조회 자격 사례다.
        let repository = try repository(meetings: "meetings-linked", sessions: "sessions-linked")
        let cancelled = [RaceMeetingCandidate(name: "Test Grand Prix", season: 2026, isCancelled: true)]
        let expected = [
            candidate(season: 2025, meetings: cancelled),
            candidate(id: 202, cancelled: true, meetings: cancelled),
            // 2099-01-01 00:00:00 UTC와 02:00:00 UTC.
            candidate(id: 303, start: 4_070_908_800, end: 4_070_916_000, meetings: cancelled)
        ]

        // Act
        let candidates = try await repository.fetchRaceCandidates(year: 2026)

        // Assert
        expectCandidates(candidates.filter { $0.linkedMeetings == cancelled }, expected)
    }

    @Test("대회 자료가 비어 있어도 세션 후보를 유지한다")
    func preservesCandidateWithoutMeetings() async throws {
        // Arrange
        let repository = try repository(meetings: "response-empty", sessions: "sessions-normal")

        // Act
        let candidates = try await repository.fetchRaceCandidates(year: 2026)

        // Assert
        #expect(candidates == [candidate(meetings: [])])
    }

    @Test("세션의 불완전 정보·잘못된 시각을 보존하고 장소만 정규화한다")
    func preservesIncompleteSessions() async throws {
        // Arrange: 각 필드를 하나씩 누락·null·해석 불가로 만든 자료와 정상 자료다.
        let repository = try repository(meetings: "meetings-normal", sessions: "sessions-incomplete")
        let incomplete = [candidate(id: nil), candidate(season: nil), candidate(kind: nil),
                          candidate(cancelled: nil), candidate(start: nil), candidate(end: nil)]
        let invalidTimes = [candidate(end: 1_767_222_000), candidate(id: 202, end: 1_767_225_600)]
        let locations = [candidate(location: nil), candidate(id: 202, location: nil),
                         candidate(id: 303, location: nil), candidate(id: 404)]
        let expected = incomplete + incomplete + incomplete + [candidate()] + invalidTimes + locations

        // Act
        let candidates = try await repository.fetchRaceCandidates(year: 2026)

        // Assert
        expectCandidates(candidates, expected)
    }

    @Test("연결 대회의 불완전 정보·빈 이름·공백 이름과 정상 정보를 모두 보존한다")
    func preservesIncompleteMeetings() async throws {
        // Arrange
        let repository = try repository(meetings: "meetings-incomplete", sessions: "sessions-normal")
        let incomplete = [
            RaceMeetingCandidate(name: nil, season: 2026, isCancelled: false),
            RaceMeetingCandidate(name: "Test Grand Prix", season: nil, isCancelled: false),
            RaceMeetingCandidate(name: "Test Grand Prix", season: 2026, isCancelled: nil)
        ]
        let blankNames = [RaceMeetingCandidate(name: "", season: 2026, isCancelled: false),
                          RaceMeetingCandidate(name: " \t\n", season: 2026, isCancelled: false)]
        let expected = candidate(meetings: incomplete + incomplete + incomplete + [meeting()] + blankNames)

        // Act
        let candidates = try await repository.fetchRaceCandidates(year: 2026)

        // Assert
        expectCandidates(candidates, [expected])
    }

    @Test("다른 시차로 표기한 같은 순간을 소수 초까지 같은 절대 시각으로 변환한다")
    func convertsAbsoluteTimes() async throws {
        // Arrange
        let repository = try repository(meetings: "meetings-normal", sessions: "sessions-time-offsets")
        let expected = [101, 202, 303].map {
            candidate(id: $0, start: 1_767_225_600.125, end: 1_767_232_800.125)
        }

        // Act
        let candidates = try await repository.fetchRaceCandidates(year: 2026)

        // Assert
        expectCandidates(candidates, expected)
    }

    @Test("세션 자료가 없으면 정상 빈 배열을 반환한다", arguments: ["meetings-normal", "response-empty"])
    func returnsEmptyCandidates(meetings: String) async throws {
        // Arrange
        let repository = try repository(meetings: meetings, sessions: "response-empty")

        // Act
        let candidates = try await repository.fetchRaceCandidates(year: 2026)

        // Assert
        #expect(candidates.isEmpty)
    }

    @Test("대회 또는 세션 응답 전체를 해석할 수 없으면 오류를 전달한다",
          arguments: ["response-malformed", "response-wrong-structure"], [true, false])
    func reportsInvalidResponse(fixture: String, invalidMeetings: Bool) async throws {
        // Arrange
        let repository = try repository(
            meetings: invalidMeetings ? fixture : "meetings-normal",
            sessions: invalidMeetings ? "sessions-normal" : fixture
        )

        // Act / Assert: 일반 오류의 구체 타입은 계약으로 요구하지 않는다.
        await #expect { try await repository.fetchRaceCandidates(year: 2026) }
        throws: { !($0 is CancellationError) }
    }

    @Test("자료 공급 실패를 정상 빈 결과로 바꾸지 않는다")
    func forwardsFailure() async {
        // Arrange
        let repository: any RaceListRepository = DemoRaceListProvider { _ in
            throw URLError(.notConnectedToInternet)
        }

        // Act / Assert
        await #expect { try await repository.fetchRaceCandidates(year: 2026) }
        throws: { !($0 is CancellationError) }
    }

    @Test("자료 공급의 취소를 CancellationError로 전달한다")
    func forwardsCancellation() async {
        // Arrange
        let repository: any RaceListRepository = DemoRaceListProvider { _ in
            throw CancellationError()
        }

        // Act / Assert
        await #expect(throws: CancellationError.self) {
            try await repository.fetchRaceCandidates(year: 2026)
        }
    }
}

// MARK: - 헬퍼

private extension RaceListRepositoryTests {

    // MARK: 입력 준비

    func repository(meetings: String, sessions: String) throws -> any RaceListRepository {
        let meetingsData = try response(meetings)
        let sessionsData = try response(sessions)
        return DemoRaceListProvider { _ in (meetingsData, sessionsData) }
    }

    func response(_ name: String) throws -> Data {
        let url = try #require(Bundle(for: Self.self).url(
            forResource: name, withExtension: "json", subdirectory: "Fixtures"
        ))
        return try Data(contentsOf: url)
    }

    // MARK: 기대값 구성

    var duplicateMeetings: [RaceMeetingCandidate] {
        [meeting(), meeting(), RaceMeetingCandidate(name: "Other GP", season: 2025, isCancelled: true)]
    }

    // 정상 기대값을 기본으로 두고 각 테스트에서 달라지는 속성을 명시한다.
    func candidate(
        id: Int? = 101, season: Int? = 2026, kind: RaceSessionKind? = .race,
        cancelled: Bool? = false, start: TimeInterval? = 1_767_225_600,
        end: TimeInterval? = 1_767_232_800, location: String? = "Test Circuit",
        meetings: [RaceMeetingCandidate]? = nil
    ) -> RaceCandidate {
        RaceCandidate(sessionID: id, season: season, kind: kind, isCancelled: cancelled,
                      startsAt: start.map { Date(timeIntervalSince1970: $0) },
                      endsAt: end.map { Date(timeIntervalSince1970: $0) },
                      location: location, linkedMeetings: meetings ?? [meeting()])
    }

    func meeting() -> RaceMeetingCandidate {
        RaceMeetingCandidate(name: "Test Grand Prix", season: 2026, isCancelled: false)
    }

    // MARK: 결과 비교

    // 후보와 연결 대회의 순서를 강제하지 않고 전체 값과 중복 횟수를 비교한다.
    func expectCandidates(_ actual: [RaceCandidate], _ expected: [RaceCandidate],
                          sourceLocation: SourceLocation = #_sourceLocation) {
        var remaining = actual
        for candidate in expected {
            let index = remaining.firstIndex { other in
                other.sessionID == candidate.sessionID && other.season == candidate.season
                    && other.kind == candidate.kind && other.isCancelled == candidate.isCancelled
                    && other.startsAt == candidate.startsAt && other.endsAt == candidate.endsAt
                    && other.location == candidate.location
                    && sameMeetings(other.linkedMeetings, candidate.linkedMeetings)
            }
            guard let index else {
                Issue.record("기대 후보가 누락되거나 값이 변경됨: \(candidate)", sourceLocation: sourceLocation)
                return
            }
            remaining.remove(at: index)
        }
        #expect(remaining.isEmpty, "기대하지 않은 후보가 남음: \(remaining)", sourceLocation: sourceLocation)
    }

    func sameMeetings(_ actual: [RaceMeetingCandidate], _ expected: [RaceMeetingCandidate]) -> Bool {
        var remaining = actual
        for meeting in expected {
            guard let index = remaining.firstIndex(of: meeting) else { return false }
            remaining.remove(at: index)
        }
        return remaining.isEmpty
    }
}
