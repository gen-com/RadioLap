//
//  DriverRadioUseCaseSpy.swift
//  RadioLapTests
//

import Foundation
import Testing

/// 조회 응답·취소를 제어하고 동기 상황 계산은 지정한 클로저에 전달한다.
/// 취소 후에도 응답을 보류해 하위 작업의 늦은 응답을 재현한다.
actor DriverRadioUseCaseSpy: DriverRadioUseCase {
    struct Request: Sendable {
        let id: Int
        let kind: RadioDataKind
        let sessionID: Int
        let driverNumber: Int
    }

    nonisolated let resolve: @Sendable (Date, [DriverLap]?, [DriverPosition]?, [DriverStint]?) -> RadioContext
    private(set) var requests: [Request] = []
    private var radioResponses: [Int: CheckedContinuation<[RadioRecord], any Error>] = [:]
    private var lapResponses: [Int: CheckedContinuation<[DriverLap], any Error>] = [:]
    private var positionResponses: [Int: CheckedContinuation<[DriverPosition], any Error>] = [:]
    private var stintResponses: [Int: CheckedContinuation<[DriverStint], any Error>] = [:]
    private(set) var cancelled: Set<Int> = []
    private var isClosed = false

    init(resolve: @escaping @Sendable (Date, [DriverLap]?, [DriverPosition]?, [DriverStint]?) -> RadioContext = { _, _, _, _ in
        Issue.record("예상하지 않은 상황 연결 요청")
        return RadioContext(lap: .notLoaded, position: .notLoaded, tyre: .lapUnavailable)
    }) {
        self.resolve = resolve
    }

    nonisolated func resolveContext(recordedAt: Date, laps: [DriverLap]?,
                                    positions: [DriverPosition]?, stints: [DriverStint]?) -> RadioContext {
        resolve(recordedAt, laps, positions, stints)
    }

    func fetchRadioRecords(sessionID: Int, driverNumber: Int) async throws -> [RadioRecord] {
        guard !isClosed else { throw CancellationError() }
        let request = Request(id: requests.count, kind: .radio, sessionID: sessionID, driverNumber: driverNumber)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                radioResponses[request.id] = continuation
                requests.append(request)
            }
        } onCancel: {
            Task { await self.recordCancellation(request.id) }
        }
    }

    func completeRadioRecords(_ request: Request, with result: Result<[RadioRecord], any Error>) throws {
        let response = radioResponses.removeValue(forKey: request.id)
        let continuation = try #require(response, "완료할 radio 요청이 없습니다.")
        continuation.resume(with: result)
    }

    func fetchLaps(sessionID: Int, driverNumber: Int) async throws -> [DriverLap] {
        guard !isClosed else { throw CancellationError() }
        let request = Request(id: requests.count, kind: .laps, sessionID: sessionID, driverNumber: driverNumber)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lapResponses[request.id] = continuation
                requests.append(request)
            }
        } onCancel: {
            Task { await self.recordCancellation(request.id) }
        }
    }

    func completeLaps(_ request: Request, with result: Result<[DriverLap], any Error>) throws {
        let response = lapResponses.removeValue(forKey: request.id)
        let continuation = try #require(response, "완료할 laps 요청이 없습니다.")
        continuation.resume(with: result)
    }

    func fetchPositions(sessionID: Int, driverNumber: Int) async throws -> [DriverPosition] {
        guard !isClosed else { throw CancellationError() }
        let request = Request(id: requests.count, kind: .positions, sessionID: sessionID, driverNumber: driverNumber)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                positionResponses[request.id] = continuation
                requests.append(request)
            }
        } onCancel: {
            Task { await self.recordCancellation(request.id) }
        }
    }

    func completePositions(_ request: Request, with result: Result<[DriverPosition], any Error>) throws {
        let response = positionResponses.removeValue(forKey: request.id)
        let continuation = try #require(response, "완료할 positions 요청이 없습니다.")
        continuation.resume(with: result)
    }

    func fetchStints(sessionID: Int, driverNumber: Int) async throws -> [DriverStint] {
        guard !isClosed else { throw CancellationError() }
        let request = Request(id: requests.count, kind: .stints, sessionID: sessionID, driverNumber: driverNumber)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                stintResponses[request.id] = continuation
                requests.append(request)
            }
        } onCancel: {
            Task { await self.recordCancellation(request.id) }
        }
    }

    func completeStints(_ request: Request, with result: Result<[DriverStint], any Error>) throws {
        let response = stintResponses.removeValue(forKey: request.id)
        let continuation = try #require(response, "완료할 stints 요청이 없습니다.")
        continuation.resume(with: result)
    }

    func request(_ kind: RadioDataKind, at index: Int = 0) async throws -> Request {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while requests.filter({ $0.kind == kind }).count <= index, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        let matching = requests.filter { $0.kind == kind }
        try #require(matching.indices.contains(index), "해당 자료의 요청이 도착하지 않았습니다.")
        return matching[index]
    }

    func waitForCancellation(of request: Request) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !cancelled.contains(request.id), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(cancelled.contains(request.id), "요청에 취소가 전달되지 않았습니다.")
    }

    /// 테스트 실패 시에도 보류 응답을 해제하고 이후 요청은 대기시키지 않는다.
    func close() {
        isClosed = true
        for response in radioResponses.values { response.resume(throwing: CancellationError()) }
        for response in lapResponses.values { response.resume(throwing: CancellationError()) }
        for response in positionResponses.values { response.resume(throwing: CancellationError()) }
        for response in stintResponses.values { response.resume(throwing: CancellationError()) }
        radioResponses.removeAll()
        lapResponses.removeAll()
        positionResponses.removeAll()
        stintResponses.removeAll()
    }

    private func recordCancellation(_ id: Int) {
        cancelled.insert(id)
    }
}
