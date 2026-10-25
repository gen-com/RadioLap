//
//  RaceDetailRepositoryTests.swift
//  RadioLapTests
//

import Foundation
import Testing

@MainActor
final class RaceDetailRepositoryTests {
    
    // MARK: - 테스트: 조회와 연결

    @Test("meeting_key 등 미사용 필드를 무시하고 참가자·결과 후보를 반환한다")
    func returnsCandidate() async throws {
        // Arrange
        let repository = try repository()
        let expected = RaceDetailCandidate(drivers: [driver()], unmatchedResults: [])

        // Act
        let actual = try await repository.fetchRaceDetailCandidate(sessionID: 1)

        // Assert
        #expect(actual == expected)
    }

    @Test("선택한 세션의 참가자·결과 자료만 읽어 연결한다", arguments: [1, -1])
    func selectsRequestedSession(_ id: Int) async throws {
        // Arrange: 요청 식별자를 공급 함수에 전달하고 해당 자료를 연결하는지 확인한다.
        let files = [
            1: (drivers: try file("drivers-normal"), results: try file("results-normal")),
            -1: (drivers: try file("drivers-second"), results: try file("results-second"))
        ]
        let repository: any RaceDetailRepository = DemoRaceDetailProvider { requested in
            #expect(requested == id)
            let selected = try #require(files[requested])
            return (try Data(contentsOf: selected.drivers), try Data(contentsOf: selected.results))
        }
        // 음수 식별자와 번호, 0·음수 순위도 제공된 값 그대로 연결한다.
        let expectedDrivers = id == 1 ? [driver()] : [
            driver(number: -7, name: "Second DRIVER", results: [result(position: 0)]),
            driver(number: 100, name: "Second DRIVER", results: [result(position: -1)])]

        // Act
        let actual = try await repository.fetchRaceDetailCandidate(sessionID: id)

        // Assert
        expectSameRecords(actual.drivers, expectedDrivers)
        #expect(actual.unmatchedResults.isEmpty)
    }

    // MARK: - 테스트: 후보와 결과 보존

    @Test("정규화·중복 제거 없이 원문과 동일·상충 후보를 보존한다")
    func preservesUnrefinedRecords() async throws {
        // Arrange
        let repository = try repository(drivers: "drivers-preserved", results: "results-preserved")
        let results = [result(), result(), result(position: 2)]
        let firstName = "  Alex DRIVER\n"
        let conflictingName = "Other DRIVER"

        // Act
        let actual = try await repository.fetchRaceDetailCandidate(sessionID: 1)

        // Assert: 순서는 강제하지 않되 중복 개수와 모든 필드를 확인한다.
        #expect(actual.drivers.count == 3)
        #expect(actual.drivers.filter { $0.name == firstName }.count == 2)
        #expect(actual.drivers.filter { $0.name == conflictingName }.count == 1)
        for value in actual.drivers {
            #expect(value.driverNumber == 7)
            #expect(value.acronym == " ")
            #expect(value.teamName == "")
            expectSameRecords(value.results, results)
        }
        #expect(actual.unmatchedResults.isEmpty)
    }

    @Test("빈 필수 이름과 선택 정보의 부재를 정제하지 않고 후보로 보존한다")
    func preservesIncompleteStrings() async throws {
        // Arrange
        let repository = try repository(drivers: "drivers-incomplete")

        // Act
        let actual = try await repository.fetchRaceDetailCandidate(sessionID: 1)

        // Assert
        #expect(actual.drivers == [driver(name: " \n", acronym: nil, team: nil)])
    }

    @Test("이름과 응답 순서가 아닌 번호로 결과를 연결하고 미연결 결과를 보존한다")
    func linksResultsByNumber() async throws {
        // Arrange
        let repository = try repository(drivers: "drivers-linked", results: "results-linked")

        // Act
        let actual = try await repository.fetchRaceDetailCandidate(sessionID: 1)

        // Assert
        #expect(actual.drivers.count == 3)
        let ranked = try #require(actual.drivers.first { $0.driverNumber == 7 })
        let missing = try #require(actual.drivers.first { $0.driverNumber == 8 })
        let unranked = try #require(actual.drivers.first { $0.driverNumber == 9 })
        #expect(actual.drivers.allSatisfy { $0.name == "Same DRIVER" })
        #expect(ranked.results == [result(position: 5, dnf: true, dns: false)])
        #expect(missing.results.isEmpty)
        #expect(unranked.results == [result(position: nil, dnf: true, dns: true, dsq: true)])
        #expect(actual.unmatchedResults == [.init(driverNumber: 99, result: result(dsq: true))])
    }

    @Test("순위 필드가 누락되어도 결과와 경기 상태를 유지한다")
    func preservesResultWithoutPosition() async throws {
        // Arrange
        let repository = try repository(results: "results-missing-position")
        let expected = RaceDetailCandidate(
            drivers: [driver(results: [result(position: nil)])], unmatchedResults: [])

        // Act
        let actual = try await repository.fetchRaceDetailCandidate(sessionID: 1)

        // Assert
        #expect(actual == expected)
    }

    @Test("빈 참가자·빈 결과·미연결 결과를 서로 구분해 보존한다",
          arguments: [(false, true), (true, true), (true, false)])
    func preservesEmptyData(_ empty: (Bool, Bool)) async throws {
        // Arrange
        let (noDrivers, noResults) = empty
        let repository = try repository(drivers: noDrivers ? "response-empty" : "drivers-normal",
                                        results: noResults ? "response-empty" : "results-normal")

        // Act
        let actual = try await repository.fetchRaceDetailCandidate(sessionID: 1)

        // Assert
        #expect(actual.drivers == (noDrivers ? [] : [driver(results: [])]))
        #expect(actual.unmatchedResults == (noResults ? [] : [.init(driverNumber: 7, result: result())]))
    }

    // MARK: - 테스트: 응답 해석과 오류

    @Test("응답 구조 오류와 필수 필드 누락을 정상 부재로 숨기지 않는다", arguments: [
        ("drivers", "drivers-missing-key"),
        ("drivers", "response-malformed"),
        ("results", "response-object"),
        ("drivers", "drivers-null-element"),
        ("results", "results-missing-status")
    ])
    func rejectsInvalidStructure(_ sample: (String, String)) async throws {
        // Arrange: 나머지 입력은 정상 파일 그대로 사용한다.
        let repository = try repository(
            drivers: sample.0 == "drivers" ? sample.1 : "drivers-normal",
            results: sample.0 == "results" ? sample.1 : "results-normal"
        )

        // Act / Assert
        await #expect { try await repository.fetchRaceDetailCandidate(sessionID: 1) }
        throws: { !($0 is CancellationError) }
    }

    @Test("사용 필드의 타입 오류와 Int 표현 범위 초과를 거부한다", arguments: [
        ("drivers", "drivers-invalid-name"),
        ("drivers", "drivers-invalid-team"),
        ("results", "results-fractional-position"),
        ("results", "results-string-position"),
        ("results", "results-null-status"),
        ("results", "results-numeric-status"),
        ("results", "results-overflow-key")
    ])
    func rejectsInvalidFieldValues(_ sample: (String, String)) async throws {
        // Arrange: 나머지 입력은 정상 파일 그대로 사용한다.
        let repository = try repository(
            drivers: sample.0 == "drivers" ? sample.1 : "drivers-normal",
            results: sample.0 == "results" ? sample.1 : "results-normal"
        )

        // Act / Assert
        await #expect { try await repository.fetchRaceDetailCandidate(sessionID: 1) }
        throws: { !($0 is CancellationError) }
    }

    @Test("요청 세션 밖의 응답이 섞이면 전체 실패한다", arguments: [
        ("drivers", "drivers-foreign-session"),
        ("results", "results-foreign-session")
    ])
    func rejectsInvalidConnection(_ sample: (String, String)) async throws {
        // Arrange: 나머지 입력은 정상 파일 그대로 사용한다.
        let repository = try repository(
            drivers: sample.0 == "drivers" ? sample.1 : "drivers-normal",
            results: sample.0 == "results" ? sample.1 : "results-normal"
        )

        // Act / Assert
        await #expect { try await repository.fetchRaceDetailCandidate(sessionID: 1) }
        throws: { !($0 is CancellationError) }
    }

    // MARK: - 테스트: 실패와 취소

    @Test("필요한 자료 읽기 실패를 부분 성공으로 바꾸지 않는다",
          arguments: ["drivers-normal", "results-normal"])
    func forwardsReadFailure(_ failing: String) async throws {
        // Arrange
        let repository = try repository(read: { url in
            if url.deletingPathExtension().lastPathComponent == failing { throw URLError(.cannotOpenFile) }
            return try Data(contentsOf: url)
        })

        // Act / Assert
        await #expect { try await repository.fetchRaceDetailCandidate(sessionID: 1) }
        throws: { !($0 is CancellationError) }
    }

    @Test("자료 공급의 취소를 CancellationError로 전달한다")
    func forwardsSupplyCancellation() async throws {
        // Arrange
        let repository = try repository(read: { _ in throw URLError(.cancelled) })

        // Act / Assert
        await #expect(throws: CancellationError.self) {
            try await repository.fetchRaceDetailCandidate(sessionID: 1)
        }
    }

    @Test("이미 취소된 호출은 자료를 읽지 않고 취소를 전달한다")
    func observesPriorCancellation() async throws {
        // Arrange
        let repository = try repository(read: { url in
            Issue.record("이미 취소된 작업에서 자료를 읽었습니다")
            return try Data(contentsOf: url)
        })
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await repository.fetchRaceDetailCandidate(sessionID: 1)
        }

        // Act / Assert
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test("자료 공급 중 관찰한 호출자 취소를 성공이나 일반 실패로 바꾸지 않는다",
          arguments: [false, true])
    func observesCancellationDuringRead(_ fail: Bool) async throws {
        // Arrange: 읽기 순서나 시간 지연에 의존하지 않고 호출 작업을 취소한다.
        let repository = try repository(read: { url in
            withUnsafeCurrentTask { $0?.cancel() }
            if fail { throw URLError(.cannotOpenFile) }
            return try Data(contentsOf: url)
        })
        let task = Task { try await repository.fetchRaceDetailCandidate(sessionID: 1) }

        // Act / Assert
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}

// MARK: - 헬퍼

private extension RaceDetailRepositoryTests {
    // MARK: 입력 준비

    // 구체 Provider 준비만 이곳에서 수행하고 검증은 Repository 계약으로 호출한다.
    func repository(
        drivers: String = "drivers-normal", results: String = "results-normal",
        read: @escaping @Sendable (URL) async throws -> Data = { try Data(contentsOf: $0) }
    ) throws -> any RaceDetailRepository {
        let driversURL = try file(drivers)
        let resultsURL = try file(results)
        return DemoRaceDetailProvider { _ in
            let driversData = try await read(driversURL)
            let resultsData = try await read(resultsURL)
            return (driversData, resultsData)
        }
    }

    func file(_ name: String) throws -> URL {
        try #require(Bundle(for: Self.self).url(forResource: name, withExtension: "json",
                                                subdirectory: "RaceDetailFixtures"))
    }

    // MARK: 기대값 구성

    func driver(number: Int = 7, name: String = "Alex DRIVER", acronym: String? = "ADR",
                team: String? = "Team", results: [RaceResult]? = nil) -> RaceDetailCandidate.Driver {
        .init(driverNumber: number, name: name, acronym: acronym, teamName: team, results: results ?? [result()])
    }

    func result(position: Int? = 1, dnf: Bool = false, dns: Bool = false, dsq: Bool = false) -> RaceResult {
        .init(position: position, didNotFinish: dnf, didNotStart: dns, isDisqualified: dsq)
    }

    // MARK: 결과 비교

    // Set으로 바꾸면 중복이 사라지므로 일치 항목을 하나씩 소모한다.
    func expectSameRecords<T: Equatable>(_ actual: [T], _ expected: [T],
                                         sourceLocation: SourceLocation = #_sourceLocation) {
        var remaining = actual
        for value in expected {
            guard let index = remaining.firstIndex(of: value) else {
                Issue.record("기대한 레코드가 없습니다: \(value)", sourceLocation: sourceLocation)
                return
            }
            remaining.remove(at: index)
        }
        #expect(remaining.isEmpty, "예상하지 않은 레코드: \(remaining)", sourceLocation: sourceLocation)
    }
}
