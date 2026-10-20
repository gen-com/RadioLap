//
//  RaceListRepositorySpy.swift
//  RadioLapTests
//

import Foundation
import Testing

/// 요청과 취소를 기록하고 응답 시점을 테스트가 제어한다. 이벤트 대기는 제한 시간을 둔다.
actor RaceListRepositorySpy: RaceListRepository {
    struct Request: Sendable {
        let id: Int
        let year: Int
        let endedBefore: Date
    }
    enum Failure: Error { case unavailable, cancelled }

    private(set) var requestCount = 0
    private var pending: [Int: CheckedContinuation<[Race], any Error>] = [:]
    private var requests: [Request] = []
    private var cancelledIDs: Set<Int> = []
    private var finished = false

    func fetchRaces(year: Int, endedBefore: Date) async throws -> [Race] {
        guard !finished else { throw CancellationError() }
        let request = Request(id: requestCount, year: year, endedBefore: endedBefore)
        requestCount += 1
        // 취소는 기록하되 응답은 테스트가 명시적으로 완료할 때까지 유지한다.
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending[request.id] = continuation
                requests.append(request)
            }
        } onCancel: {
            Task { await self.recordCancellation(request.id) }
        }
    }

    private func recordCancellation(_ id: Int) {
        cancelledIDs.insert(id)
    }

    func waitForCancellation(_ id: Int) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !cancelledIDs.contains(id), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(cancelledIDs.contains(id), "제한 시간 안에 요청 취소가 전달되어야 합니다.")
    }

    func wasCancelled(_ id: Int) -> Bool { cancelledIDs.contains(id) }

    func nextRequest() async throws -> Request {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while requests.isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(!requests.isEmpty, "제한 시간 안에 Repository를 호출해야 합니다.")
        return requests.removeFirst()
    }

    func finishPendingRequests() {
        finished = true
        let continuations = Array(pending.values)
        pending.removeAll()
        for continuation in continuations {
            continuation.resume(throwing: CancellationError())
        }
    }

    func complete(_ id: Int, with result: Result<[Race], Failure>) {
        guard let continuation = pending.removeValue(forKey: id)
        else { preconditionFailure("완료할 요청이 없습니다.") }
        switch result {
        case .success(let races): continuation.resume(returning: races)
        case .failure(.cancelled): continuation.resume(throwing: CancellationError())
        case .failure(let error): continuation.resume(throwing: error)
        }
    }
}
