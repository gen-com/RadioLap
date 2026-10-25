//
//  RaceListViewModelTests.swift
//  RadioLapTests
//

import Foundation
import Observation
import Testing

@MainActor
final class RaceListViewModelTests {

    // MARK: - 테스트: 초기 상태와 조회

    @Test("초기 상태는 idle이며 UseCase와 시계를 호출하지 않는다")
    func startsIdleWithoutRequest() async throws {
        // Arrange
        var clockReads = 0
        try await withPresentation(now: {
            clockReads += 1
            return Date(timeIntervalSince1970: 1000)
        }) { presentation, useCase in
            // Act / Assert
            #expect(presentation.state == .idle)
            #expect(await useCase.requests.isEmpty)
            #expect(clockReads == 0)
        }
    }

    @Test("load는 관찰 가능한 loading으로 즉시 전환하고 시즌과 기준 시각을 전달한다")
    func startsLoading() async throws {
        // Arrange
        let now = Date(timeIntervalSince1970: 1000)
        var clockReads = 0
        try await withPresentation(now: {
            clockReads += 1
            return now
        }) { presentation, useCase in
            await confirmation("loading 변경 알림") { changed in
                withObservationTracking {
                    _ = presentation.state
                } onChange: { changed() }

                // Act
                presentation.load()

                // Assert
                #expect(presentation.state == .loading)
            }
            let request = try await useCase.request(at: 0)
            #expect(request.year == 2026)
            #expect(request.endedBefore == now)
            #expect(clockReads == 1)
        }
    }

    // MARK: - 테스트: 결과 반영

    @Test("UseCase가 반환한 값과 순서를 그대로 content에 반영하고 변경을 알린다")
    func preservesContentOrder() async throws {
        // Arrange: ViewModel이 다시 정렬하는 오류를 잡기 위해 공급 순서를 최신순과 다르게 둔다.
        let races = [Race(sessionID: 20, season: 2026, name: "Earlier GP", startsAt: Date(timeIntervalSince1970: 100), location: nil),
                     Race(sessionID: 10, season: 2026, name: "Later GP", startsAt: Date(timeIntervalSince1970: 200), location: "Circuit")]
        try await withPresentation { presentation, useCase in
            presentation.load()
            let request = try await useCase.request(at: 0)
            try await confirmation("content 변경 알림") { changed in
                withObservationTracking {
                    _ = presentation.state
                } onChange: { changed() }

                // Act
                try await useCase.complete(request, with: .success(races))

                // Assert
                try await waitForState(.content(races), in: presentation)
            }
        }
    }

    @Test("빈 결과는 content가 아닌 empty로 반영한다")
    func showsEmptyResult() async throws {
        try await withPresentation { presentation, useCase in
            // Arrange
            presentation.load()
            let request = try await useCase.request(at: 0)

            // Act
            try await useCase.complete(request, with: .success([]))

            // Assert
            try await waitForState(.empty, in: presentation)
        }
    }

    @Test("일반 오류는 다시 시도 안내가 있는 failed로 반영한다")
    func showsFailure() async throws {
        try await withPresentation { presentation, useCase in
            // Arrange
            presentation.load()
            let request = try await useCase.request(at: 0)

            // Act
            try await useCase.complete(request, with: .failure(URLError(.notConnectedToInternet)))

            // Assert
            try await waitForState(.failed(message: "레이스 목록을 불러오지 못했습니다. 다시 시도해주세요."), in: presentation)
        }
    }

    @Test("UseCase의 CancellationError는 실패 안내 없이 idle로 반영한다")
    func showsCancellation() async throws {
        try await withPresentation { presentation, useCase in
            // Arrange
            presentation.load()
            let request = try await useCase.request(at: 0)

            // Act
            try await useCase.complete(request, with: .failure(CancellationError()))

            // Assert
            try await waitForState(.idle, in: presentation)
        }
    }

    @Test("실패 후 재시도는 새 기준 시각으로 조회하고 성공 결과를 반영한다")
    func retriesAfterFailure() async throws {
        // Arrange
        var now = Date(timeIntervalSince1970: 1000)
        var clockReads = 0
        try await withPresentation(now: {
            clockReads += 1
            return now
        }) { presentation, useCase in
            presentation.load()
            let first = try await useCase.request(at: 0)
            try await useCase.complete(first, with: .failure(URLError(.timedOut)))
            try await waitForState(.failed(message: "레이스 목록을 불러오지 못했습니다. 다시 시도해주세요."), in: presentation)

            // Act
            now = Date(timeIntervalSince1970: 2000)
            presentation.load()

            // Assert
            #expect(presentation.state == .loading)
            let retry = try await useCase.request(at: 1)
            #expect(first.endedBefore == Date(timeIntervalSince1970: 1000))
            #expect(retry.endedBefore == now)
            #expect(retry.year == 2026)
            #expect(clockReads == 2)
            try await useCase.complete(retry, with: .success(sampleRaces))
            try await waitForState(.content(sampleRaces), in: presentation)
        }
    }

    // MARK: - 테스트: 취소와 최신 요청

    @Test("진행 중 요청을 취소하면 즉시 idle로 바뀌고 다시 조회할 수 있다")
    func cancelsAndLoadsAgain() async throws {
        try await withPresentation { presentation, useCase in
            // Arrange
            presentation.load()
            let first = try await useCase.request(at: 0)

            // Act
            presentation.cancel()

            // Assert
            #expect(presentation.state == .idle)
            try await useCase.waitForCancellation(of: first)
            // 취소된 작업의 실제 종료를 기다리지 않고 다음 조회를 시작한다.
            presentation.load()
            let next = try await useCase.request(at: 1)
            try await useCase.complete(next, with: .success(sampleRaces))
            try await waitForState(.content(sampleRaces), in: presentation)
        }
    }

    @Test("명시적으로 취소한 요청의 늦은 성공·실패·취소는 idle을 변경하지 않는다",
          arguments: LateResponse.allCases)
    func ignoresCancelledResponse(response: LateResponse) async throws {
        try await withPresentation { presentation, useCase in
            // Arrange
            presentation.load()
            let request = try await useCase.request(at: 0)
            presentation.cancel()
            #expect(presentation.state == .idle)

            // Act / Assert
            try await expectStateRemains(.idle, in: presentation) {
                try await useCase.complete(request, with: result(response))
            }
        }
    }

    @Test("새 조회가 이전 요청을 취소하고 이전 응답은 최신 결과를 덮지 않는다",
          arguments: LateResponse.allCases)
    func keepsLatestResult(response: LateResponse) async throws {
        try await withPresentation { presentation, useCase in
            // Arrange
            presentation.load()
            let old = try await useCase.request(at: 0)
            presentation.load()
            let latest = try await useCase.request(at: 1)
            try await useCase.waitForCancellation(of: old)
            try await useCase.complete(latest, with: .success(sampleRaces))
            try await waitForState(.content(sampleRaces), in: presentation)

            // Act / Assert
            try await expectStateRemains(.content(sampleRaces), in: presentation) {
                try await useCase.complete(old, with: result(response))
            }
        }
    }

    @Test("이전 요청이 먼저 끝나도 최신 loading을 유지하고 현재 요청을 취소할 수 있다")
    func preservesCurrentRequestAfterOldResponse() async throws {
        try await withPresentation { presentation, useCase in
            // Arrange
            presentation.load()
            let old = try await useCase.request(at: 0)
            presentation.load()
            let latest = try await useCase.request(at: 1)

            // Act / Assert
            try await expectStateRemains(.loading, in: presentation) {
                try await useCase.complete(old, with: .success([]))
            }
            presentation.cancel()
            #expect(presentation.state == .idle)
            try await useCase.waitForCancellation(of: latest)
        }
    }

    @Test("완료 상태에서 cancel은 상태를 유지하고 load는 새 조회를 시작한다",
          arguments: CompletedState.allCases)
    func keepsCompletedState(state: CompletedState) async throws {
        try await withPresentation { presentation, useCase in
            // Arrange / Assert: 최초 idle에서도 cancel은 상태를 바꾸지 않는다.
            presentation.cancel()
            #expect(presentation.state == .idle)
            presentation.load()
            let request = try await useCase.request(at: 0)
            let expected: RaceListState
            switch state {
            case .content:
                try await useCase.complete(request, with: .success(sampleRaces))
                expected = .content(sampleRaces)
            case .empty:
                try await useCase.complete(request, with: .success([]))
                expected = .empty
            case .failed:
                try await useCase.complete(request, with: .failure(URLError(.timedOut)))
                expected = .failed(message: "레이스 목록을 불러오지 못했습니다. 다시 시도해주세요.")
            }
            try await waitForState(expected, in: presentation)

            // Act
            presentation.cancel()

            // Assert
            #expect(presentation.state == expected)

            // Act: 완료 상태에서도 다시 조회할 수 있다.
            presentation.load()

            // Assert
            #expect(presentation.state == .loading)
            let next = try await useCase.request(at: 1)
            try await useCase.complete(next, with: .success([]))
            try await waitForState(.empty, in: presentation)
        }
    }
}

// MARK: - 테스트 입력

private extension RaceListViewModelTests {
    var sampleRaces: [Race] {
        [Race(sessionID: 99, season: 2026, name: "Test Grand Prix", startsAt: Date(timeIntervalSince1970: 500), location: "Circuit")]
    }

    func result(_ response: LateResponse) -> Result<[Race], any Error> {
        switch response {
        case .success: .success([])
        case .failure: .failure(URLError(.timedOut))
        case .cancellation: .failure(CancellationError())
        }
    }
}

// MARK: - 준비와 정리

private extension RaceListViewModelTests {
    /// 각 테스트가 독립적인 대상과 대역을 사용하며, 중간 검증 실패 시에도 미완료 요청을 해제한다.
    func withPresentation(
        now: @escaping () -> Date = { Date(timeIntervalSince1970: 1000) },
        _ test: (any RaceListPresentation, RaceListUseCaseSpy) async throws -> Void
    ) async throws {
        let useCase = RaceListUseCaseSpy()
        let presentation: any RaceListPresentation = RaceListViewModel(useCase: useCase, now: now)
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

private extension RaceListViewModelTests {
    func waitForState(_ expected: RaceListState, in presentation: any RaceListPresentation) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while presentation.state != expected, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(presentation.state == expected, "예상 상태에 도달하지 않았습니다.")
    }

    /// 늦은 응답 전달 전 관찰을 시작해 200ms 동안 상태 변경이 없는지 확인한다.
    /// 이 제한된 관찰 구간은 내부 작업의 종료나 이후 모든 시점의 무변경을 보장하지 않는다.
    func expectStateRemains(
        _ expected: RaceListState,
        in presentation: any RaceListPresentation,
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
        }
    }
}

// MARK: - 매개변수 사례

extension RaceListViewModelTests {
    enum LateResponse: CaseIterable, Sendable { case success, failure, cancellation }
    enum CompletedState: CaseIterable, Sendable { case content, empty, failed }
}
