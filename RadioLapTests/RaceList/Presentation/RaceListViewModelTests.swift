//
//  RaceListViewModelTests.swift
//  RadioLapTests
//

import Foundation
import Observation
import Testing

@MainActor
final class RaceListViewModelTests {
    private let repository: RaceListRepositorySpy
    private let viewModel: any RaceListViewModelProtocol
    private let failureState = RaceListState.failed(message: "레이스 목록을 불러오지 못했습니다. 다시 시도해주세요.")

    init() {
        let repository = RaceListRepositorySpy()
        self.repository = repository
        viewModel = RaceListViewModel(repository: repository, now: { Date(timeIntervalSince1970: 1000) })
    }

    isolated deinit {
        viewModel.cancel()
        let repository = repository
        Task {
            await repository.finishPendingRequests()
        }
    }

    private func race(_ id: Int, start: TimeInterval) -> Race {
        Race(sessionID: id, name: "Race \(id)", startsAt: Date(timeIntervalSince1970: start), location: nil)
    }

    @Test("초기에는 조회하거나 기준 시각을 읽지 않는다")
    func initialState() async {
        // Arrange
        var clockCalls = 0
        let viewModel: any RaceListViewModelProtocol = RaceListViewModel(repository: repository, now: {
            clockCalls += 1
            return Date(timeIntervalSince1970: 1000)
        })
        defer { viewModel.cancel() }

        // Act: 초기 상태를 읽는다.

        // Assert
        #expect(viewModel.state == .idle)
        #expect(await repository.requestCount == 0)
        #expect(clockCalls == 0)
    }

    @Test("load의 loading 전환을 관찰할 수 있다")
    func stateChangesAreObservable() async {
        // Arrange
        await confirmation("상태 변경 알림") { changed in
            withObservationTracking {
                _ = viewModel.state
            } onChange: {
                changed()
            }

            // Act
            viewModel.load()

            // Assert
            #expect(viewModel.state == .loading)
        }
    }

    @Test("조회 결과에 맞는 상태와 안내 메시지로 전환하며 변경을 관찰할 수 있다",
          arguments: [Response.content, .empty, .failure, .cancellation])
    func observesResultState(outcome: Response) async throws {
        // Arrange
        viewModel.load()
        let request = try await repository.nextRequest()
        let result = response(outcome)
        let expected = expectedState(outcome)
        try await confirmation("조회 결과의 상태 변경 알림") { changed in
            withObservationTracking {
                _ = viewModel.state
            } onChange: {
                changed()
            }

            // Act
            await repository.complete(request.id, with: result)

            // Assert
            try await waitForState(expected, in: viewModel)
        }
    }

    @Test("load는 즉시 loading으로 전환하고 기준 시각을 한 번 읽어 조회 인자를 전달한다")
    func startsLoadingWithExpectedArguments() async throws {
        // Arrange
        let before = Date(timeIntervalSince1970: 1000)
        var clockCalls = 0
        let viewModel: any RaceListViewModelProtocol = RaceListViewModel(repository: repository, now: {
            clockCalls += 1
            return before
        })
        defer { viewModel.cancel() }

        // Act
        viewModel.load()

        // Assert
        #expect(viewModel.state == .loading)
        #expect(clockCalls == 1)
        let request = try await repository.nextRequest()
        #expect(request.year == 2026)
        #expect(request.endedBefore == before)
    }

    @Test("시작 시각 내림차순과 동률 식별자 오름차순으로 정렬하고 반환 필드를 보존한다")
    func sortsContentPreservingValues() async throws {
        // Arrange
        let old = race(3, start: 100)
        let second = race(2, start: 200)
        let first = Race(sessionID: 1, name: "First", startsAt: Date(timeIntervalSince1970: 200), location: "Circuit")

        viewModel.load()
        let request = try await repository.nextRequest()

        // Act
        await repository.complete(request.id, with: .success([second, old, first]))

        // Assert
        try await waitForState(.content([first, second, old]), in: viewModel)
    }

    @Test("content·empty·failed 모두 load로 새 기준 시각의 조회를 시작한다", arguments: [Response.content, .failure, .empty], [false, true])
    func reloadAfterCompletion(outcome: Response, empty: Bool) async throws {
        // Arrange
        var clockCalls = 0
        var now = Date(timeIntervalSince1970: 1000)
        let viewModel: any RaceListViewModelProtocol = RaceListViewModel(repository: repository, now: {
            clockCalls += 1
            return now
        })
        defer { viewModel.cancel() }
        viewModel.load()
        let first = try await repository.nextRequest()
        let firstResult: Result<[Race], RaceListRepositorySpy.Failure> = response(outcome)
        await repository.complete(first.id, with: firstResult)
        let expected: RaceListState = expectedState(outcome)
        try await waitForState(expected, in: viewModel)

        // Act
        now = Date(timeIntervalSince1970: 2000)
        viewModel.load()

        // Assert
        #expect(viewModel.state == .loading)
        let second = try await repository.nextRequest()
        #expect(first.endedBefore == Date(timeIntervalSince1970: 1000))
        #expect(second.endedBefore == Date(timeIntervalSince1970: 2000))
        #expect(second.year == 2026)
        // Act: 재조회 응답을 전달한다.
        let result = empty ? [] : [race(9, start: 500)]
        await repository.complete(second.id, with: .success(result))

        // Assert
        try await waitForState(empty ? .empty : .content(result), in: viewModel)
        #expect(clockCalls == 2)
    }

    @Test("cancel은 즉시 idle로 전환하며, 취소를 무시한 응답 이후에도 재조회할 수 있다", arguments: [Response.content, .failure, .cancellation])
    func explicitCancellation(outcome: Response) async throws {
        // Arrange: 공통 대상은 init에서 준비한다.

        viewModel.load()
        let request = try await repository.nextRequest()

        // Act
        viewModel.cancel()

        // Assert
        #expect(viewModel.state == .idle)
        try await repository.waitForCancellation(request.id)
        // Act / Assert: 취소를 무시한 응답도 상태를 변경하지 않는다.
        try await expectStateRemains(.idle, in: viewModel) {
            await repository.complete(request.id, with: response(outcome))
        }

        // Act: 취소 이후 재조회한다.
        viewModel.load()
        let next = try await repository.nextRequest()
        await repository.complete(next.id, with: .success([]))

        // Assert
        try await waitForState(.empty, in: viewModel)
    }

    @Test("별도 cancel 없이 B를 호출하면 A가 취소되고, A의 응답 3종은 B의 진행·완료 상태를 덮지 않는다", arguments: [Response.content, .failure, .cancellation], [CurrentState.loading, .content, .empty, .failed, .idle])
    func ignoresOldResponse(outcome: Response, newState: CurrentState) async throws {
        // Arrange: 공통 대상은 init에서 준비한다.
        viewModel.load()
        let old = try await repository.nextRequest()
        viewModel.load()
        let new = try await repository.nextRequest()
        try await repository.waitForCancellation(old.id)
        let newRaces = [race(99, start: 500)]
        let expected: RaceListState
        switch newState {
        case .content:
            await repository.complete(new.id, with: .success(newRaces))
            expected = .content(newRaces)
        case .empty:
            await repository.complete(new.id, with: .success([]))
            expected = .empty
        case .failed:
            await repository.complete(new.id, with: .failure(.unavailable))
            expected = failureState
        case .idle:
            await repository.complete(new.id, with: .failure(.cancelled))
            expected = .idle
        case .loading:
            expected = .loading
        }
        try await waitForState(expected, in: viewModel)
        // Act / Assert: 응답 전달 전부터 공개 상태 변경을 관찰한다.
        try await expectStateRemains(expected, in: viewModel) {
            await repository.complete(old.id, with: response(outcome))
        }
        #expect(await repository.wasCancelled(new.id) == false)
        #expect(await repository.requestCount == 2)
        if newState == .loading {
            await repository.complete(new.id, with: .success(newRaces))
            try await waitForState(.content(newRaces), in: viewModel)
        }
    }

    @Test("이전 요청이 늦게 끝나도 현재 요청을 취소할 수 있다",
          arguments: [Response.content, .failure, .cancellation])
    func oldResponsePreservesCurrentCancellation(outcome: Response) async throws {
        // Arrange: 공통 대상은 init에서 준비한다.

        viewModel.load()
        let old = try await repository.nextRequest()
        viewModel.load()
        let new = try await repository.nextRequest()

        // Act / Assert
        try await expectStateRemains(.loading, in: viewModel) {
            await repository.complete(old.id, with: response(outcome))
        }

        // Act
        viewModel.cancel()

        // Assert
        #expect(viewModel.state == .idle)
        try await repository.waitForCancellation(new.id)
        try await expectStateRemains(.idle, in: viewModel) {
            await repository.complete(new.id, with: .success([race(2, start: 200)]))
        }
    }

    @Test("세 요청의 모든 응답 순서에서 C만 결과를 반영한다", arguments: [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]])
    func latestOfThreeRequests(order: [Int]) async throws {
        // Arrange: 공통 대상은 init에서 준비한다.
        var requests: [RaceListRepositorySpy.Request] = []
        for _ in 0..<3 {
            viewModel.load()
            requests.append(try await repository.nextRequest())
        }
        try await repository.waitForCancellation(requests[0].id)
        try await repository.waitForCancellation(requests[1].id)

        // Assert
        #expect(await repository.wasCancelled(requests[2].id) == false)
        var latestCompleted = false
        // Act / Assert: 지정한 순서로 응답하며 각 단계의 공개 상태를 확인한다.
        for index in order {
            let result = [race(index + 1, start: Double(index * 100))]
            latestCompleted = latestCompleted || index == 2
            let expected: RaceListState = latestCompleted ? .content([race(3, start: 200)]) : .loading
            if index == 2 {
                await repository.complete(requests[index].id, with: .success(result))
                try await waitForState(expected, in: viewModel)
            } else {
                try await expectStateRemains(expected, in: viewModel) {
                    await repository.complete(requests[index].id, with: .success(result))
                }
            }
        }
        #expect(await repository.requestCount == 3)
    }

    @Test("중단점 없이 연속 호출해도 이전 Task가 취소되며 마지막 작업만 Repository를 호출한다")
    func replacementBeforeTaskStarts() async throws {
        // Arrange
        var clockCalls = 0
        var now = Date(timeIntervalSince1970: 1000)
        let viewModel: any RaceListViewModelProtocol = RaceListViewModel(repository: repository, now: {
            clockCalls += 1
            return now
        })
        defer { viewModel.cancel() }

        // Act
        viewModel.load()
        now = Date(timeIntervalSince1970: 2000)
        viewModel.load()
        now = Date(timeIntervalSince1970: 3000)
        viewModel.load()
        let request = try await repository.nextRequest()
        await repository.complete(request.id, with: .success([]))

        // Assert
        try await waitForState(.empty, in: viewModel)
        try await expectStateRemains(.empty, in: viewModel) { await Task.yield() }
        #expect(await repository.requestCount == 1)
        #expect(clockCalls == 3)
        #expect(request.endedBefore == Date(timeIntervalSince1970: 3000))
    }

    @Test("실행 전 취소는 Repository를 호출하지 않으며 기준 시각을 한 번 읽고 재조회할 수 있다")
    func cancellationBeforeTaskStarts() async throws {
        // Arrange
        var clockCalls = 0
        var now = Date(timeIntervalSince1970: 1000)
        let viewModel: any RaceListViewModelProtocol = RaceListViewModel(repository: repository, now: {
            clockCalls += 1
            return now
        })
        defer { viewModel.cancel() }

        // Act: MainActor를 양보하기 전에 취소한다.
        viewModel.load()
        viewModel.cancel()

        // Assert
        #expect(viewModel.state == .idle)
        #expect(clockCalls == 1)
        try await expectStateRemains(.idle, in: viewModel) { await Task.yield() }
        #expect(await repository.requestCount == 0)

        // Act: 취소 이후 다시 조회한다.
        now = Date(timeIntervalSince1970: 2000)
        viewModel.load()
        let request = try await repository.nextRequest()
        await repository.complete(request.id, with: .success([]))

        // Assert
        try await waitForState(.empty, in: viewModel)
        #expect(request.endedBefore == Date(timeIntervalSince1970: 2000))
        #expect(clockCalls == 2)
    }

    @Test("진행 중인 요청이 없으면 cancel은 idle·content·empty·failed를 유지한다", arguments: [Response.content, .failure, .empty])
    func cancellationWithoutActiveRequest(outcome: Response) async throws {
        // Arrange: 공통 대상은 init에서 준비한다.
        viewModel.cancel()

        // Assert
        #expect(viewModel.state == .idle)
        viewModel.load()
        let request = try await repository.nextRequest()
        let result: Result<[Race], RaceListRepositorySpy.Failure> = response(outcome)
        await repository.complete(request.id, with: result)
        let expected: RaceListState = expectedState(outcome)
        try await waitForState(expected, in: viewModel)
        let previous = viewModel.state

        // Act
        viewModel.cancel()

        // Assert
        #expect(viewModel.state == previous)
        #expect(await repository.requestCount == 1)
    }

    @Test("호출자 취소는 내부 작업에 전파되지 않고 명시적 cancel로 중단한다", arguments: [true, false])
    func callerCancellationDoesNotCancelLoad(cancelBeforeLoad: Bool) async throws {
        // Arrange: 조회 시작 전·후에 호출 작업을 취소한다.

        // Act
        let caller = Task {
            if cancelBeforeLoad { withUnsafeCurrentTask { $0?.cancel() } }
            viewModel.load()
            if !cancelBeforeLoad { withUnsafeCurrentTask { $0?.cancel() } }
        }
        await caller.value
        let request = try await repository.nextRequest()

        // Assert
        #expect(viewModel.state == .loading)
        viewModel.cancel()
        try await repository.waitForCancellation(request.id)
        try await expectStateRemains(.idle, in: viewModel) {
            await repository.complete(request.id, with: .success([]))
        }
    }

    private let stateTimeout: Duration = .seconds(3)
    private let observationDuration: Duration = .seconds(1)
    private let pollingInterval: Duration = .milliseconds(10)

    /// 공개 상태를 최대 3초 기다리고, 예상 상태에 도달하면 바로 반환한다.
    private func waitForState(_ expected: RaceListState, in viewModel: any RaceListViewModelProtocol) async throws {
        let deadline = ContinuousClock.now.advanced(by: stateTimeout)
        while viewModel.state != expected, ContinuousClock.now < deadline {
            try await Task.sleep(for: pollingInterval)
        }
        try #require(viewModel.state == expected, "제한 시간 안에 예상 상태에 도달해야 합니다.")
    }

    /// 응답을 전달하기 전 변경 추적을 등록하여 관찰 중 일시적인 상태 변경도 검출한다.
    /// 1초 관찰은 내부 Task의 종료를 보장하지 않으며, 관찰 구간 이후의 변경은 검출하지 못한다.
    private func expectStateRemains(
        _ expected: RaceListState,
        in viewModel: any RaceListViewModelProtocol,
        after action: () async -> Void
    ) async throws {
        try #require(viewModel.state == expected)
        try await confirmation("상태가 변경되지 않는다", expectedCount: 0) { changed in
            withObservationTracking {
                _ = viewModel.state
            } onChange: {
                changed()
            }
            await action()
            try await Task.sleep(for: observationDuration)
            #expect(viewModel.state == expected)
        }
    }

    private func response(_ outcome: Response) -> Result<[Race], RaceListRepositorySpy.Failure> {
        switch outcome {
        case .content: .success([race(1, start: 100)])
        case .empty: .success([])
        case .failure: .failure(.unavailable)
        case .cancellation: .failure(.cancelled)
        }
    }

    private func expectedState(_ outcome: Response) -> RaceListState {
        switch outcome {
        case .content: .content([race(1, start: 100)])
        case .empty: .empty
        case .failure: failureState
        case .cancellation: .idle
        }
    }

    enum Response: Sendable { case content, empty, failure, cancellation }
    enum CurrentState: Sendable { case loading, content, empty, failed, idle }
}
