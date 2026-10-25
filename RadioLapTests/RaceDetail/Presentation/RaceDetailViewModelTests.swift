//
//  RaceDetailViewModelTests.swift
//  RadioLapTests
//

import Foundation
import Observation
import Testing

@MainActor
final class RaceDetailViewModelTests {
    
    // MARK: - 테스트: 초기 상태와 조회

    @Test("초기화는 Race를 보존하고 조회 없이 idle로 시작한다")
    func startsIdleWithoutRequest() async throws {
        // Arrange
        try await withPresentation { presentation, useCase in
            // Act / Assert
            #expect(presentation.race == selectedRace)
            #expect(presentation.state == .idle)
            #expect(await useCase.requests.isEmpty)
            presentation.cancel()
            #expect(presentation.state == .idle)
        }
    }

    @Test("load는 관찰 가능한 loading으로 즉시 전환하고 선택한 Race를 전달한다")
    func startsLoading() async throws {
        // Arrange
        try await withPresentation { presentation, useCase in
            await confirmation("loading 변경 알림") { changed in
                withObservationTracking {
                    _ = presentation.state
                } onChange: { changed() }

                // Act
                presentation.load()

                // Assert
                #expect(presentation.state == .loading)
                #expect(presentation.race == selectedRace)
            }
            let request = try await useCase.request(at: 0)
            #expect(request.race == selectedRace)
        }
    }

    // MARK: - 테스트: 그룹과 결과 구성

    @Test("결과·순위 유무로 그룹을 나누고 그룹별로 정렬하며 참가자와 상태를 보존한다")
    func groupsAndSortsDrivers() async throws {
        // Arrange: 순위 간격·동률을 포함하고 상태 플래그가 그룹을 바꾸지 않는지 확인한다.
        let first = driver(20, result: result(1, dnf: true))
        let tiedFirst = driver(8, result: result(5, dsq: true))
        let tiedSecond = driver(9, result: result(5))
        let unrankedFirst = driver(10, result: result(nil, dnf: true, dns: true, dsq: true))
        let unrankedSecond = driver(11, result: result(nil))
        let missingFirst = driver(12)
        let missingSecond = driver(13)
        let input = RaceDetail(race: selectedRace, drivers: [
            missingSecond, unrankedSecond, tiedSecond, missingFirst, first, unrankedFirst, tiedFirst])
        let expected: RaceDetailState = .content([
            .init(kind: .ranked, drivers: [first, tiedFirst, tiedSecond]),
            .init(kind: .unranked, drivers: [unrankedFirst, unrankedSecond]),
            .init(kind: .resultsUnavailable, drivers: [missingFirst, missingSecond])])
        try await withPresentation { presentation, useCase in
            presentation.load()
            let request = try await useCase.request(at: 0)
            try await confirmation("content 변경 알림") { changed in
                withObservationTracking {
                    _ = presentation.state
                } onChange: { changed() }

                // Act
                try await useCase.complete(request, with: .success(input))

                // Assert
                try await waitForState(expected, in: presentation)
            }
        }
    }

    @Test("참가자가 있는 그룹만 반환하며 다른 빈 그룹을 추가하지 않는다",
          arguments: [RaceDriverGroup.Kind.ranked, .unranked, .resultsUnavailable])
    func omitsEmptyGroups(_ kind: RaceDriverGroup.Kind) async throws {
        // Arrange
        let participant: RaceDriver
        switch kind {
        case .ranked: participant = driver(7, result: result(1))
        case .unranked: participant = driver(7, result: result(nil))
        case .resultsUnavailable: participant = driver(7)
        }
        try await withPresentation { presentation, useCase in
            presentation.load()
            let request = try await useCase.request(at: 0)

            // Act
            try await useCase.complete(request, with: .success(RaceDetail(race: selectedRace, drivers: [participant])))

            // Assert
            try await waitForState(.content([.init(kind: kind, drivers: [participant])]), in: presentation)
        }
    }

    // MARK: - 테스트: 완료 상태와 재조회

    @Test("성공·빈 결과·실패·취소를 구분하고 완료 상태에서 cancel은 유지, load는 재조회한다",
          arguments: CompletedState.allCases)
    func handlesCompletionAndReload(_ state: CompletedState) async throws {
        try await withPresentation { presentation, useCase in
            // Arrange
            presentation.load()
            let first = try await useCase.request(at: 0)
            let response: Result<RaceDetail, any Error>
            let expected: RaceDetailState
            switch state {
            case .content:
                response = .success(sampleDetail)
                expected = sampleContent
            case .empty:
                response = .success(RaceDetail(race: selectedRace, drivers: []))
                expected = .empty
            case .failed:
                response = .failure(URLError(.timedOut))
                expected = .failed
            case .cancelled:
                response = .failure(CancellationError())
                expected = .cancelled
            }

            // Act / Assert
            try await useCase.complete(first, with: response)
            try await waitForState(expected, in: presentation)
            if case .cancelled = state {
                // 다른 동작으로 자동 재조회를 취소해 숨기지 않도록 먼저 관찰한다.
                // 기존 헬퍼의 200ms 관찰 구간 안에서 상태와 요청 수를 확인한다.
                try await expectStateRemains(.cancelled, in: presentation) {}
                #expect(await useCase.requests.count == 1)
            }
            presentation.cancel()
            #expect(presentation.state == expected)
            #expect(await useCase.requests.count == 1)

            // Act: 실패·취소 후 재시도를 포함해 완료 상태에서 같은 Race로 다시 조회한다.
            presentation.load()

            // Assert
            #expect(presentation.state == .loading)
            let next = try await useCase.request(at: 1)
            #expect(next.race == selectedRace)
            try await useCase.complete(next, with: .success(sampleDetail))
            try await waitForState(sampleContent, in: presentation)
        }
    }

    // MARK: - 테스트: 취소와 최신 요청

    @Test("진행 중 요청은 즉시 cancelled로 전환하고 취소된 작업 종료 전에 다시 조회할 수 있다")
    func cancelsAndLoadsAgain() async throws {
        try await withPresentation { presentation, useCase in
            // Arrange
            presentation.load()
            let first = try await useCase.request(at: 0)

            // Act
            presentation.cancel()

            // Assert
            #expect(presentation.state == .cancelled)
            #expect(presentation.race == selectedRace)
            try await useCase.waitForCancellation(of: first)
            presentation.load()
            let next = try await useCase.request(at: 1)
            #expect(next.race == selectedRace)
            try await useCase.complete(next, with: .success(sampleDetail))
            try await waitForState(sampleContent, in: presentation)
        }
    }

    @Test("명시적으로 취소한 요청의 늦은 성공·실패·취소는 cancelled를 변경하지 않는다",
          arguments: LateResponse.allCases)
    func ignoresCancelledResponse(_ response: LateResponse) async throws {
        try await withPresentation { presentation, useCase in
            // Arrange
            presentation.load()
            let request = try await useCase.request(at: 0)
            presentation.cancel()

            // Act / Assert
            try await expectStateRemains(.cancelled, in: presentation) {
                try await useCase.complete(request, with: lateResult(response))
            }
        }
    }

    @Test("새 조회는 이전 요청을 취소하고 이전 응답은 최신 결과를 덮지 않는다",
          arguments: LateResponse.allCases)
    func keepsLatestResult(_ response: LateResponse) async throws {
        try await withPresentation { presentation, useCase in
            // Arrange
            presentation.load()
            let old = try await useCase.request(at: 0)
            presentation.load()
            let latest = try await useCase.request(at: 1)
            try await useCase.waitForCancellation(of: old)
            try await useCase.complete(latest, with: .success(sampleDetail))
            try await waitForState(sampleContent, in: presentation)

            // Act / Assert
            try await expectStateRemains(sampleContent, in: presentation) {
                try await useCase.complete(old, with: lateResult(response))
            }
        }
    }

    @Test("이전 응답이 먼저 도착해도 최신 loading과 현재 요청의 취소 연결을 유지한다",
          arguments: LateResponse.allCases)
    func preservesCurrentRequest(_ response: LateResponse) async throws {
        try await withPresentation { presentation, useCase in
            // Arrange
            presentation.load()
            let old = try await useCase.request(at: 0)
            presentation.load()
            let latest = try await useCase.request(at: 1)

            // Act / Assert
            try await expectStateRemains(.loading, in: presentation) {
                try await useCase.complete(old, with: lateResult(response))
            }
            presentation.cancel()
            #expect(presentation.state == .cancelled)
            try await useCase.waitForCancellation(of: latest)
        }
    }
}

// MARK: - 테스트 입력

private extension RaceDetailViewModelTests {
    var selectedRace: Race {
        Race(sessionID: 99, season: 2026, name: "Test GP", startsAt: Date(timeIntervalSince1970: 500), location: "Circuit")
    }

    var sampleDetail: RaceDetail {
        RaceDetail(race: selectedRace, drivers: [driver(7, result: result(1))])
    }

    var sampleContent: RaceDetailState {
        .content([.init(kind: .ranked, drivers: sampleDetail.drivers)])
    }

    func driver(_ number: Int, result: RaceResult? = nil) -> RaceDriver {
        .init(driverNumber: number, name: "Driver \(number)", acronym: nil, teamName: "Team", result: result)
    }

    func result(_ position: Int?, dnf: Bool = false, dns: Bool = false, dsq: Bool = false) -> RaceResult {
        .init(position: position, didNotFinish: dnf, didNotStart: dns, isDisqualified: dsq)
    }

    func lateResult(_ response: LateResponse) -> Result<RaceDetail, any Error> {
        switch response {
        case .success: .success(RaceDetail(race: selectedRace, drivers: []))
        case .failure: .failure(URLError(.timedOut))
        case .cancellation: .failure(CancellationError())
        }
    }
}

// MARK: - 준비와 정리

private extension RaceDetailViewModelTests {
    // 각 테스트 종료 시 보류 중인 요청을 해제한다. 중간 검증 실패도 정리 대상이다.
    func withPresentation(
        _ test: (any RaceDetailPresentation, RaceDetailUseCaseSpy) async throws -> Void
    ) async throws {
        let useCase = RaceDetailUseCaseSpy()
        let presentation: any RaceDetailPresentation = RaceDetailViewModel(race: selectedRace, useCase: useCase)
        do {
            try await test(presentation, useCase)
        } catch {
            presentation.cancel()
            await useCase.close()
            throw error
        }
        presentation.cancel()
        await useCase.close()
    }
}

// MARK: - 비동기 상태 확인

private extension RaceDetailViewModelTests {
    func waitForState(_ expected: RaceDetailState, in presentation: any RaceDetailPresentation) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while presentation.state != expected, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(presentation.state == expected, "예상 상태에 도달하지 않았습니다.")
        #expect(presentation.race == selectedRace)
    }

    // 관찰 구간은 늦은 응답 후 200ms로 한정하며, 내부 작업 종료를 보장하지 않는다.
    func expectStateRemains(
        _ expected: RaceDetailState,
        in presentation: any RaceDetailPresentation,
        after action: () async throws -> Void
    ) async throws {
        try #require(presentation.state == expected)
        try await confirmation("늦은 응답으로 상태가 변경되지 않는다", expectedCount: 0) { changed in
            withObservationTracking {
                _ = presentation.state
            } onChange: { changed() }
            try await action()
            try await Task.sleep(for: .milliseconds(200))
            #expect(presentation.state == expected)
            #expect(presentation.race == selectedRace)
        }
    }
}

// MARK: - 매개변수 사례

extension RaceDetailViewModelTests {
    enum LateResponse: CaseIterable, Sendable { case success, failure, cancellation }
    enum CompletedState: CaseIterable, Sendable { case content, empty, failed, cancelled }
}
