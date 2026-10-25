//
//  RaceListUseCaseSpy.swift
//  RadioLapTests
//

import Foundation
import Testing

/// 요청 인자와 취소를 기록하며, 테스트가 응답 시점을 지정한다.
/// 취소만으로 응답을 끝내지 않아 취소를 무시하는 하위 작업도 재현할 수 있다.
actor RaceListUseCaseSpy: RaceListUseCase {
    struct Request: Sendable {
        let id: Int
        let year: Int
        let endedBefore: Date
    }

    private(set) var requests: [Request] = []
    private var pending: [Int: CheckedContinuation<[Race], any Error>] = [:]
    private var cancelled: Set<Int> = []
    private var isClosed = false

    func fetchRaces(year: Int, endedBefore: Date) async throws -> [Race] {
        guard !isClosed else { throw CancellationError() }
        let request = Request(id: requests.count, year: year, endedBefore: endedBefore)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending[request.id] = continuation
                requests.append(request)
            }
        } onCancel: {
            Task { await self.recordCancellation(request.id) }
        }
    }

    func request(at index: Int) async throws -> Request {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while requests.count <= index, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(requests.indices.contains(index), "UseCase 요청이 도착하지 않았습니다.")
        return requests[index]
    }

    func waitForCancellation(of request: Request) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !cancelled.contains(request.id), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(cancelled.contains(request.id), "요청에 취소가 전달되지 않았습니다.")
    }

    func complete(_ request: Request, with result: Result<[Race], any Error>) throws {
        let pendingResponse = pending.removeValue(forKey: request.id)
        let continuation = try #require(pendingResponse, "완료할 요청이 없습니다.")
        continuation.resume(with: result)
    }

    /// 테스트 성공·실패와 관계없이 미완료 요청을 해제한다. 이후 요청도 보류하지 않는다.
    func close() {
        isClosed = true
        let continuations = Array(pending.values)
        pending.removeAll()
        for continuation in continuations {
            continuation.resume(throwing: CancellationError())
        }
    }

    private func recordCancellation(_ id: Int) {
        cancelled.insert(id)
    }
}
