//
//  RaceListUseCaseTests.swift
//  RadioLapTests
//

import Foundation
import Testing

@MainActor
final class RaceListUseCaseTests {

    // MARK: - 테스트: 조회와 선별

    @Test("정상 후보를 식별자·시즌·이름·시작 시각·장소가 유지된 레이스로 반환한다")
    func returnsExpectedRace() async throws {
        // Arrange
        let useCase = useCase(candidates: [candidate()])
        let expected = Race(sessionID: 101, season: 2026, name: "Test Grand Prix", startsAt: start, location: "Test Circuit")

        // Act
        let races = try await useCase.fetchRaces(year: 2026, endedBefore: cutoff)

        // Assert
        #expect(races == [expected])
    }

    @Test("요청 시즌을 Repository에 전달하고 같은 시즌의 결승을 반환한다", arguments: [2025, 2026])
    func forwardsSeason(year: Int) async throws {
        // Arrange
        let input = candidate(season: year, meetings: [meeting(season: year)])
        let repository = CandidateRepositoryStub { requestedYear in
            #expect(requestedYear == year)
            return [input]
        }
        let useCase: any RaceListUseCase = RaceListInteractor(repository: repository)
        let expected = Race(sessionID: 101, season: year, name: "Test Grand Prix", startsAt: start, location: "Test Circuit")

        // Act
        let races = try await useCase.fetchRaces(year: year, endedBefore: cutoff)

        // Assert
        #expect(races == [expected])
    }

    @Test("종료 시각이 전달받은 기준보다 이른 경우에만 포함한다", arguments: [-1.0, 0.0, 1.0])
    func appliesEndBoundary(secondsAfterEnd: Double) async throws {
        // Arrange: 실제 현재 시각이 아닌 같은 후보와 전달된 기준만으로 결과가 달라져야 한다.
        let useCase = useCase(candidates: [candidate()])
        let boundary = end.addingTimeInterval(secondsAfterEnd)
        let expected: [Race] = secondsAfterEnd > 0
            ? [Race(sessionID: 101, season: 2026, name: "Test Grand Prix", startsAt: start, location: "Test Circuit")]
            : []

        // Act
        let races = try await useCase.fetchRaces(year: 2026, endedBefore: boundary)

        // Assert
        #expect(races == expected)
    }

    @Test("다른 시즌·비결승·취소된 세션 또는 대회를 제외하고 정상 결승은 유지한다")
    func selectsEligibleRaces() async throws {
        // Arrange: 식별자를 나누어 충돌 정책과 선별 정책을 구분한다.
        let input = [candidate(id: 1, season: 2025, meetings: [meeting(season: 2025)]),
                     candidate(id: 2, kind: .other), candidate(id: 3, cancelled: true),
                     candidate(id: 4, meetings: [meeting(cancelled: true)]), candidate()]
        let useCase = useCase(candidates: input)
        let expected = Race(sessionID: 101, season: 2026, name: "Test Grand Prix", startsAt: start, location: "Test Circuit")

        // Act
        let races = try await useCase.fetchRaces(year: 2026, endedBefore: cutoff)

        // Assert
        #expect(races == [expected])
    }

    @Test("후보가 없으면 정상 빈 목록을 반환한다")
    func returnsEmptyList() async throws {
        // Arrange
        let useCase = useCase(candidates: [])

        // Act
        let races = try await useCase.fetchRaces(year: 2026, endedBefore: cutoff)

        // Assert
        #expect(races.isEmpty)
    }

    // MARK: - 테스트: 불완전 정보와 연결

    @Test("필수 세션 정보가 없거나 시각 관계가 잘못되면 해당 후보만 제외한다")
    func excludesInvalidSessions() async throws {
        // Arrange
        let invalid = [candidate(id: nil), candidate(season: nil), candidate(kind: nil),
                       candidate(cancelled: nil), candidate(startsAt: nil), candidate(endsAt: nil),
                       candidate(endsAt: start), candidate(endsAt: start.addingTimeInterval(-1))]
        let healthy = candidate(id: 99)
        let expected = Race(sessionID: 99, season: 2026, name: "Test Grand Prix", startsAt: start, location: "Test Circuit")

        for input in invalid {
            // Act: 제외 대상만 있는 경우와 다른 정상 결승이 함께 있는 경우를 확인한다.
            let empty = try await useCase(candidates: [input]).fetchRaces(year: 2026, endedBefore: cutoff)
            let mixed = try await useCase(candidates: [input, healthy]).fetchRaces(year: 2026, endedBefore: cutoff)

            // Assert
            #expect(empty.isEmpty, "제외할 입력: \(input)")
            #expect(mixed == [expected], "제외할 입력: \(input)")
        }
    }

    @Test("연결 누락·대회 필수 정보 부족·시즌 불일치가 있으면 해당 후보만 제외한다")
    func excludesInvalidMeetings() async throws {
        // Arrange
        let invalid = [candidate(meetings: []), candidate(meetings: [meeting(name: nil)]),
                       candidate(meetings: [meeting(name: "")]), candidate(meetings: [meeting(name: " \t\n")]),
                       candidate(meetings: [meeting(season: nil)]), candidate(meetings: [meeting(cancelled: nil)]),
                       candidate(meetings: [meeting(season: 2025)])]
        let healthy = candidate(id: 99)
        let expected = Race(sessionID: 99, season: 2026, name: "Test Grand Prix", startsAt: start, location: "Test Circuit")

        for input in invalid {
            // Act
            let empty = try await useCase(candidates: [input]).fetchRaces(year: 2026, endedBefore: cutoff)
            let mixed = try await useCase(candidates: [input, healthy]).fetchRaces(year: 2026, endedBefore: cutoff)

            // Assert
            #expect(empty.isEmpty, "제외할 입력: \(input)")
            #expect(mixed == [expected], "제외할 입력: \(input)")
        }
    }

    @Test("충돌 없는 불완전 연결 대회와 정상 대회가 함께 있으면 정상 대회로 구성한다", arguments: [false, true])
    func usesValidLinkedMeeting(reversed: Bool) async throws {
        // Arrange
        let meetings = [meeting(name: nil), meeting(season: nil), meeting(cancelled: nil), meeting()]
        let input = candidate(meetings: reversed ? Array(meetings.reversed()) : meetings)
        let useCase = useCase(candidates: [input])
        let expected = Race(sessionID: 101, season: 2026, name: "Test Grand Prix", startsAt: start, location: "Test Circuit")

        // Act
        let races = try await useCase.fetchRaces(year: 2026, endedBefore: cutoff)

        // Assert
        #expect(races == [expected])
    }

    @Test("서로 다른 불완전 세션의 필수 정보를 합쳐 레이스를 만들지 않는다", arguments: [false, true])
    func doesNotCombineIncompleteSessions(reversed: Bool) async throws {
        // Arrange: 두 후보를 합치면 시작·종료 시각이 채워지지만 각각은 유효하지 않다.
        let incomplete = [candidate(startsAt: nil), candidate(endsAt: nil)]
        let ordered = reversed ? Array(incomplete.reversed()) : incomplete
        let useCase = useCase(candidates: ordered + [candidate(id: 99)])
        let expected = Race(sessionID: 99, season: 2026, name: "Test Grand Prix", startsAt: start, location: "Test Circuit")

        // Act
        let races = try await useCase.fetchRaces(year: 2026, endedBefore: cutoff)

        // Assert
        #expect(races == [expected])
    }

    @Test("불완전 연결 대회의 필수 정보를 합쳐 레이스를 만들지 않는다", arguments: [false, true])
    func doesNotCombineIncompleteMeetings(reversed: Bool) async throws {
        // Arrange
        let meetings = [meeting(name: nil), meeting(season: nil)]
        let input = candidate(meetings: reversed ? Array(meetings.reversed()) : meetings)
        let useCase = useCase(candidates: [input])

        // Act
        let races = try await useCase.fetchRaces(year: 2026, endedBefore: cutoff)

        // Assert
        #expect(races.isEmpty)
    }

    // MARK: - 테스트: 중복과 충돌 우선순위

    @Test("동일한 세션·대회 중복은 하나로 합치고 이름이 같은 다른 식별자는 유지한다", arguments: [false, true])
    func mergesIdenticalDuplicates(reversed: Bool) async throws {
        // Arrange
        let repeated = candidate(meetings: [meeting(), meeting()])
        let input = [repeated, repeated, candidate(id: 202)]
        let useCase = useCase(candidates: reversed ? Array(input.reversed()) : input)
        let expected = [101, 202].map {
            Race(sessionID: $0, season: 2026, name: "Test Grand Prix", startsAt: start, location: "Test Circuit")
        }

        // Act
        let races = try await useCase.fetchRaces(year: 2026, endedBefore: cutoff)

        // Assert
        #expect(races == expected)
    }

    @Test("필수 값·조회 자격 충돌은 선별보다 먼저 검사해 같은 식별자 전체를 제외한다", arguments: [false, true])
    func excludesConflictingCandidates(reversed: Bool) async throws {
        // Arrange: 종류·시즌·취소 조건으로 먼저 선별하면 충돌이 사라지는 사례도 포함한다.
        let conflicts = [candidate(meetings: [meeting(name: "Other GP")]),
                         candidate(startsAt: start.addingTimeInterval(1)),
                         candidate(endsAt: end.addingTimeInterval(1)),
                         candidate(season: 2025), candidate(kind: .other), candidate(cancelled: true),
                         candidate(meetings: [meeting(season: 2025)]),
                         candidate(meetings: [meeting(cancelled: true)])]
        let expected = Race(sessionID: 99, season: 2026, name: "Test Grand Prix", startsAt: start, location: "Test Circuit")

        for conflict in conflicts {
            let pair = [candidate(), conflict]
            let ordered = reversed ? Array(pair.reversed()) : pair
            // Act
            let empty = try await useCase(candidates: ordered).fetchRaces(year: 2026, endedBefore: cutoff)
            let mixed = try await useCase(candidates: ordered + [candidate(id: 99)])
                .fetchRaces(year: 2026, endedBefore: cutoff)

            // Assert
            #expect(empty.isEmpty, "충돌 후보: \(conflict)")
            #expect(mixed == [expected], "충돌 후보: \(conflict)")
        }
    }

    @Test("한 후보에 연결된 대회의 이름·시즌·취소 여부가 충돌해도 결승 전체를 제외한다", arguments: [false, true])
    func excludesConflictingLinkedMeetings(reversed: Bool) async throws {
        // Arrange
        let conflicts = [meeting(name: "Other GP"), meeting(season: 2025), meeting(cancelled: true)]
        for conflict in conflicts {
            let meetings = [meeting(), conflict]
            let input = candidate(meetings: reversed ? Array(meetings.reversed()) : meetings)
            let useCase = useCase(candidates: [input, candidate(id: 99)])
            let expected = Race(sessionID: 99, season: 2026, name: "Test Grand Prix", startsAt: start, location: "Test Circuit")

            // Act
            let races = try await useCase.fetchRaces(year: 2026, endedBefore: cutoff)

            // Assert
            #expect(races == [expected], "충돌 대회: \(conflict)")
        }
    }

    @Test("이름 없는 불완전 취소 후보도 충돌 판단에 포함한다", arguments: [false, true])
    func includesIncompleteConflict(reversed: Bool) async throws {
        // Arrange
        let input = [candidate(), candidate(cancelled: true, meetings: [meeting(name: nil)])]
        let useCase = useCase(candidates: reversed ? Array(input.reversed()) : input)

        // Act
        let races = try await useCase.fetchRaces(year: 2026, endedBefore: cutoff)

        // Assert
        #expect(races.isEmpty)
    }

    @Test("이름만 부족하고 확인 가능한 값이 같은 후보는 정상 후보를 제거하지 않는다",
          arguments: [nil, "", " \t\n"] as [String?], [false, true])
    func preservesHealthyDuplicate(name: String?, reversed: Bool) async throws {
        // Arrange
        let input = [candidate(meetings: [meeting(name: name)]), candidate()]
        let useCase = useCase(candidates: reversed ? Array(input.reversed()) : input)
        let expected = Race(sessionID: 101, season: 2026, name: "Test Grand Prix", startsAt: start, location: "Test Circuit")

        // Act
        let races = try await useCase.fetchRaces(year: 2026, endedBefore: cutoff)

        // Assert
        #expect(races == [expected])
    }

    // MARK: - 테스트: 장소와 정렬

    @Test("장소가 없거나 같은 장소가 반복되면 확인 가능한 값을 유지한다",
          arguments: [nil, "Test Circuit"] as [String?], [false, true])
    func preservesLocation(location: String?, includeMissing: Bool) async throws {
        // Arrange: 모두 없음, 모두 동일, 일부 누락을 검증한다.
        let input = [candidate(location: location), candidate(location: includeMissing ? nil : location)]
        let useCase = useCase(candidates: input)
        let expected = Race(sessionID: 101, season: 2026, name: "Test Grand Prix", startsAt: start, location: location)

        // Act
        let races = try await useCase.fetchRaces(year: 2026, endedBefore: cutoff)

        // Assert
        #expect(races == [expected])
    }

    @Test("장소만 충돌하면 결승은 유지하고 장소를 nil로 반환한다", arguments: [false, true])
    func clearsConflictingLocation(reversed: Bool) async throws {
        // Arrange
        let input = [candidate(), candidate(location: "Other Circuit"), candidate(location: nil)]
        let useCase = useCase(candidates: reversed ? Array(input.reversed()) : input)
        let expected = Race(sessionID: 101, season: 2026, name: "Test Grand Prix", startsAt: start, location: nil)

        // Act
        let races = try await useCase.fetchRaces(year: 2026, endedBefore: cutoff)

        // Assert
        #expect(races == [expected])
    }

    @Test("입력 순서와 무관하게 시작 시각 내림차순·동률 식별자 오름차순으로 반환한다", arguments: [false, true])
    func sortsRaces(reversed: Bool) async throws {
        // Arrange
        let later = start.addingTimeInterval(60)
        let input = [candidate(id: 303), candidate(id: 202, startsAt: later), candidate(id: 101, startsAt: later)]
        let useCase = useCase(candidates: reversed ? Array(input.reversed()) : input)
        let expected = [Race(sessionID: 101, season: 2026, name: "Test Grand Prix", startsAt: later, location: "Test Circuit"),
                        Race(sessionID: 202, season: 2026, name: "Test Grand Prix", startsAt: later, location: "Test Circuit"),
                        Race(sessionID: 303, season: 2026, name: "Test Grand Prix", startsAt: start, location: "Test Circuit")]

        // Act
        let races = try await useCase.fetchRaces(year: 2026, endedBefore: cutoff)

        // Assert
        #expect(races == expected)
    }

    // MARK: - 테스트: 오류와 취소

    @Test("Repository의 전체 실패를 빈 목록으로 바꾸지 않는다")
    func forwardsFailure() async {
        // Arrange
        let repository = CandidateRepositoryStub { _ in throw URLError(.notConnectedToInternet) }
        let useCase: any RaceListUseCase = RaceListInteractor(repository: repository)

        // Act / Assert: 일반 오류의 구체 타입은 강제하지 않는다.
        await #expect { try await useCase.fetchRaces(year: 2026, endedBefore: cutoff) }
        throws: { !($0 is CancellationError) }
    }

    @Test("Repository의 취소를 CancellationError로 전달한다")
    func forwardsCancellation() async {
        // Arrange
        let repository = CandidateRepositoryStub { _ in throw CancellationError() }
        let useCase: any RaceListUseCase = RaceListInteractor(repository: repository)

        // Act / Assert
        await #expect(throws: CancellationError.self) {
            try await useCase.fetchRaces(year: 2026, endedBefore: cutoff)
        }
    }

    @Test("후보 조회 중 호출 작업이 취소되면 정상 후보를 받아도 취소로 종료한다")
    func cooperatesWithCallerCancellation() async {
        // Arrange: 대기 장치 없이 조회 작업 안에서 취소 상태를 만들고 정상 후보를 돌려준다.
        let input = [candidate()]
        let repository = CandidateRepositoryStub { _ in
            withUnsafeCurrentTask { $0?.cancel() }
            return input
        }
        let useCase: any RaceListUseCase = RaceListInteractor(repository: repository)
        let boundary = cutoff
        let task = Task { try await useCase.fetchRaces(year: 2026, endedBefore: boundary) }
        defer { task.cancel() }

        // Act / Assert
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}

// MARK: - 공통 준비

private extension RaceListUseCaseTests {
    // 2026-01-01 00:00, 02:00, 03:00 UTC. 실제 현재 시각과 독립적인 입력이다.
    var start: Date { Date(timeIntervalSince1970: 1_767_225_600) }
    var end: Date { Date(timeIntervalSince1970: 1_767_232_800) }
    var cutoff: Date { Date(timeIntervalSince1970: 1_767_236_400) }

    func useCase(candidates: [RaceCandidate]) -> any RaceListUseCase {
        RaceListInteractor(repository: CandidateRepositoryStub { _ in candidates })
    }

    func candidate(
        id: Int? = 101, season: Int? = 2026, kind: RaceSessionKind? = .race,
        cancelled: Bool? = false,
        startsAt: Date? = Date(timeIntervalSince1970: 1_767_225_600),
        endsAt: Date? = Date(timeIntervalSince1970: 1_767_232_800),
        location: String? = "Test Circuit", meetings: [RaceMeetingCandidate]? = nil
    ) -> RaceCandidate {
        RaceCandidate(sessionID: id, season: season, kind: kind, isCancelled: cancelled,
                      startsAt: startsAt, endsAt: endsAt, location: location,
                      linkedMeetings: meetings ?? [meeting()])
    }

    func meeting(name: String? = "Test Grand Prix", season: Int? = 2026,
                 cancelled: Bool? = false) -> RaceMeetingCandidate {
        RaceMeetingCandidate(name: name, season: season, isCancelled: cancelled)
    }
}
