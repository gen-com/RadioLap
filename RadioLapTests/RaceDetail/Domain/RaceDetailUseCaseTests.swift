//
//  RaceDetailUseCaseTests.swift
//  RadioLapTests
//

import Foundation
import Testing

@MainActor
final class RaceDetailUseCaseTests {
    
    // MARK: - 테스트: 조회와 기본 정보

    @Test("입력 Race의 식별자를 Repository에 전달하고 상세에 Race를 보존한다", arguments: [2, 0, -1])
    func returnsRequestedDetail(_ id: Int) async throws {
        // Arrange
        let input = candidate()
        let repository = RaceDetailRepositoryStub { requested in
            #expect(requested == id)
            return input
        }
        let useCase: any RaceDetailUseCase = RaceDetailInteractor(repository: repository)
        let expected = detail(id: id)

        // Act
        let actual = try await useCase.fetchRaceDetail(race: race(id: id))

        // Assert
        #expect(actual == expected)
    }

    @Test("참가자에 연결되지 않은 결과를 버리거나 참가자를 생성하지 않는다", arguments: [false, true])
    func rejectsUnmatchedResults(_ emptyDrivers: Bool) async {
        // Arrange
        let input = candidate(drivers: emptyDrivers ? [] : [driver()],
                              unmatched: [.init(driverNumber: 99, result: result())])
        let useCase = useCase(input)

        // Act / Assert
        await #expect { try await useCase.fetchRaceDetail(race: race()) }
        throws: { !($0 is CancellationError) }
    }

    // MARK: - 테스트: 문자열 정규화

    @Test("표시 문자열의 앞뒤 공백만 제거하고 내부 내용과 약칭을 보존한다")
    func normalizesDisplayStrings() async throws {
        // Arrange
        let input = candidate(
            drivers: [driver(name: "  Álex\nDRIVER\t", acronym: " long-code ", team: "  Team  Name!\n")])
        let useCase = useCase(input)
        let expected = RaceDetail(race: race(), drivers: [
            .init(driverNumber: 7, name: "Álex\nDRIVER", acronym: "long-code",
                  teamName: "Team  Name!", result: result())])

        // Act
        let actual = try await useCase.fetchRaceDetail(race: race())

        // Assert
        #expect(actual == expected)
    }

    @Test("선택 정보의 부재·빈 값·공백은 nil로 정리하고 참가자를 유지한다",
          arguments: [nil, "", " \t\n\u{00A0}"] as [String?])
    func normalizesAbsentOptionalStrings(_ value: String?) async throws {
        // Arrange
        let useCase = useCase(candidate(drivers: [driver(acronym: value, team: value)]))
        let expected = RaceDetail(race: race(), drivers: [
            .init(driverNumber: 7, name: "Alex DRIVER", acronym: nil, teamName: nil, result: result())])

        // Act
        let actual = try await useCase.fetchRaceDetail(race: race())

        // Assert
        #expect(actual == expected)
    }

    @Test("정규화 후 필수 이름이 비면 정상 레코드가 함께 있어도 전체 실패한다")
    func rejectsBlankNames() async {
        // Arrange
        let inputs = [candidate(drivers: [driver(name: "\u{00A0}"), driver()]),
                      candidate(drivers: [driver(number: 8, name: ""), driver()])]
        for input in inputs {
            let useCase = useCase(input)

            // Act / Assert
            await #expect { try await useCase.fetchRaceDetail(race: race()) }
            throws: { !($0 is CancellationError) }
        }
    }

    // MARK: - 테스트: 중복과 충돌

    @Test("정규화 후 동일한 참가자·결과 중복을 하나로 합친다", arguments: [false, true])
    func mergesEquivalentDuplicates(_ reversed: Bool) async throws {
        // Arrange
        let drivers = [driver(acronym: nil, team: " ", results: [result(), result()]),
                       driver(name: " Alex DRIVER\n", acronym: "", team: nil)]
        let useCase = useCase(candidate(drivers: reversed ? Array(drivers.reversed()) : drivers))
        let expected = detail(drivers: [.init(driverNumber: 7, name: "Alex DRIVER", acronym: nil,
                                              teamName: nil, result: result())])

        // Act
        let actual = try await useCase.fetchRaceDetail(race: race())

        // Assert
        #expect(actual == expected)
    }

    @Test("참가자·결과의 값 충돌은 순서와 관계없이 전체 실패한다", arguments: [false, true])
    func rejectsConflictingRecords(_ reversed: Bool) async {
        // Arrange: 단순 정규화로 같아지지 않는 내부 공백·대소문자 차이도 보존한다.
        let inputs = [
            candidate(drivers: [driver(), driver(name: "alex DRIVER")]),
            candidate(drivers: [driver(team: "Team Name"), driver(team: "Team  Name")]),
            candidate(drivers: [driver(results: [result(), result(position: 2)])]),
            // 같은 참가자의 서로 다른 레코드에 나뉜 결과도 충돌을 검사한다.
            candidate(drivers: [driver(results: [result()]), driver(results: [result(position: 2)])]),
            candidate(drivers: [driver(results: [result(), result(dnf: true)])])]
        for input in inputs {
            let prepared = reversed ? reversingRecords(input) : input
            let useCase = useCase(prepared)

            // Act / Assert
            await #expect { try await useCase.fetchRaceDetail(race: race()) }
            throws: { !($0 is CancellationError) }
        }
    }

    // MARK: - 테스트: 결과 구성

    @Test("결과 미제공·순위 없음·동률·순위 간격과 독립적인 상태를 보존한다")
    func preservesResults() async throws {
        // Arrange
        let ranked = result(position: 5, dnf: true, dns: false)
        let unranked = result(position: nil, dnf: true, dns: true, dsq: true)
        let drivers = [driver(number: 7, results: []), driver(number: 8, results: [unranked]),
                       driver(number: 9, results: [ranked]), driver(number: 10, results: [result(position: 5, dsq: true)])]
        let useCase = useCase(candidate(drivers: drivers))
        let expected: [RaceDriver] = [
            .init(driverNumber: 7, name: "Alex DRIVER", acronym: "ADR", teamName: "Team", result: nil),
            .init(driverNumber: 8, name: "Alex DRIVER", acronym: "ADR", teamName: "Team", result: unranked),
            .init(driverNumber: 9, name: "Alex DRIVER", acronym: "ADR", teamName: "Team", result: ranked),
            .init(driverNumber: 10, name: "Alex DRIVER", acronym: "ADR", teamName: "Team", result: result(position: 5, dsq: true))]

        // Act
        let actual = try await useCase.fetchRaceDetail(race: race())

        // Assert: 반환 순서는 계약이 아니므로 검증할 때만 번호순으로 맞춘다.
        #expect(actual.drivers.sorted { $0.driverNumber < $1.driverNumber } == expected)
    }

    @Test("참가자·결과가 모두 비면 레이스 정보를, 결과만 비면 참가자도 유지한다", arguments: [false, true])
    func returnsNormalEmptyData(_ noDrivers: Bool) async throws {
        // Arrange
        let useCase = useCase(candidate(drivers: noDrivers ? [] : [driver(results: [])]))
        let expected = detail(drivers: noDrivers ? [] : [
            .init(driverNumber: 7, name: "Alex DRIVER", acronym: "ADR", teamName: "Team", result: nil)])

        // Act
        let actual = try await useCase.fetchRaceDetail(race: race())

        // Assert
        #expect(actual == expected)
    }

    @Test("입력 Race의 시즌·절대 시각·이름·장소를 재해석하거나 정규화하지 않는다")
    func preservesInputRace() async throws {
        // Arrange: 날짜는 2100년이지만 시즌은 입력값을 사용하며 문자열 공백도 유지한다.
        let selected = Race(sessionID: 2, season: 2099, name: "  New GP\n",
                            startsAt: Date(timeIntervalSince1970: 4_102_444_800), location: "  New Circuit\t")
        let useCase = useCase(candidate())
        let expected = RaceDetail(race: selected, drivers: detail().drivers)

        // Act
        let actual = try await useCase.fetchRaceDetail(race: selected)

        // Assert
        #expect(actual == expected)
    }

    // MARK: - 테스트: 실패와 취소

    @Test("Repository 실패를 빈 성공이나 취소로 바꾸지 않는다")
    func forwardsFailure() async {
        // Arrange
        let repository = RaceDetailRepositoryStub { _ in throw URLError(.notConnectedToInternet) }
        let useCase: any RaceDetailUseCase = RaceDetailInteractor(repository: repository)

        // Act / Assert
        await #expect { try await useCase.fetchRaceDetail(race: race()) }
        throws: { !($0 is CancellationError) }
    }

    @Test("Repository 취소를 CancellationError로 전달한다")
    func forwardsCancellation() async {
        // Arrange
        let repository = RaceDetailRepositoryStub { _ in throw CancellationError() }
        let useCase: any RaceDetailUseCase = RaceDetailInteractor(repository: repository)

        // Act / Assert
        await #expect(throws: CancellationError.self) { try await useCase.fetchRaceDetail(race: race()) }
    }

    @Test("이미 취소된 호출은 Repository를 호출하지 않고 취소를 전달한다")
    func observesPriorCancellation() async {
        // Arrange
        let input = candidate()
        let repository = RaceDetailRepositoryStub { _ in
            Issue.record("이미 취소된 작업에서 Repository를 호출했습니다")
            return input
        }
        let useCase: any RaceDetailUseCase = RaceDetailInteractor(repository: repository)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await useCase.fetchRaceDetail(race: race())
        }

        // Act / Assert
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test("후보 조회 중 호출자 취소를 관찰하면 성공·실패보다 취소를 전달한다", arguments: [false, true])
    func observesCancellationDuringFetch(_ fail: Bool) async {
        // Arrange
        let input = candidate()
        let repository = RaceDetailRepositoryStub { _ in
            withUnsafeCurrentTask { $0?.cancel() }
            if fail { throw URLError(.notConnectedToInternet) }
            return input
        }
        let useCase: any RaceDetailUseCase = RaceDetailInteractor(repository: repository)
        let task = Task { try await useCase.fetchRaceDetail(race: race()) }

        // Act / Assert
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test("진행 중인 호출 작업의 취소가 Repository에도 전달된다")
    func propagatesCallerCancellation() async {
        // Arrange: 무한 대기를 두지 않고 취소 여부를 직접 확인한 후 정상 후보를 돌려준다.
        let input = candidate()
        let started = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        let repository = RaceDetailRepositoryStub { _ in
            started.continuation.yield(())
            started.continuation.finish()
            for await _ in release.stream { break }
            #expect(Task.isCancelled)
            return input
        }
        let useCase: any RaceDetailUseCase = RaceDetailInteractor(repository: repository)
        let task = Task {
            defer { started.continuation.finish() }
            return try await useCase.fetchRaceDetail(race: race())
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
}

// MARK: - 공통 준비

private extension RaceDetailUseCaseTests {
    var start: Date { Date(timeIntervalSince1970: 1_767_225_600) }

    func useCase(_ input: RaceDetailCandidate) -> any RaceDetailUseCase {
        RaceDetailInteractor(repository: RaceDetailRepositoryStub { _ in input })
    }

    func candidate(drivers: [RaceDetailCandidate.Driver]? = nil,
                   unmatched: [RaceDetailCandidate.UnmatchedResult] = []) -> RaceDetailCandidate {
        .init(drivers: drivers ?? [driver()], unmatchedResults: unmatched)
    }

    func race(id: Int = 1) -> Race {
        .init(sessionID: id, season: 2026, name: "Test GP", startsAt: start, location: "Circuit")
    }

    func driver(number: Int = 7, name: String = "Alex DRIVER", acronym: String? = "ADR",
                team: String? = "Team", results: [RaceResult]? = nil) -> RaceDetailCandidate.Driver {
        .init(driverNumber: number, name: name, acronym: acronym, teamName: team, results: results ?? [result()])
    }

    func result(position: Int? = 1, dnf: Bool = false, dns: Bool = false, dsq: Bool = false) -> RaceResult {
        .init(position: position, didNotFinish: dnf, didNotStart: dns, isDisqualified: dsq)
    }

    func detail(id: Int = 1, drivers: [RaceDriver]? = nil) -> RaceDetail {
        .init(race: race(id: id), drivers: drivers ?? [
            .init(driverNumber: 7, name: "Alex DRIVER", acronym: "ADR", teamName: "Team", result: result())])
    }

    // 원래 연결 관계를 유지하고 각 배열의 순서만 뒤집는다.
    func reversingRecords(_ input: RaceDetailCandidate) -> RaceDetailCandidate {
        let drivers = input.drivers.reversed().map {
            RaceDetailCandidate.Driver(driverNumber: $0.driverNumber, name: $0.name, acronym: $0.acronym,
                                       teamName: $0.teamName, results: Array($0.results.reversed()))
        }
        return .init(drivers: drivers, unmatchedResults: Array(input.unmatchedResults.reversed()))
    }
}
