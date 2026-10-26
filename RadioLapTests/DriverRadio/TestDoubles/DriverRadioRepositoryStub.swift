//
//  DriverRadioRepositoryStub.swift
//  RadioLapTests
//

import Foundation
import Testing

/// Domain 자료·오류만 공급한다. 정리·시점 연결·취소 정책은 수행하지 않는다.
nonisolated struct DriverRadioRepositoryStub: DriverRadioRepository {
    var loadRadioRecords: @Sendable (Int, Int) async throws -> [RadioRecord] = { _, _ in
        Issue.record("예상하지 않은 라디오 조회")
        return []
    }
    var loadLaps: @Sendable (Int, Int) async throws -> [DriverLap] = { _, _ in
        Issue.record("예상하지 않은 랩 조회")
        return []
    }
    var loadPositions: @Sendable (Int, Int) async throws -> [DriverPosition] = { _, _ in
        Issue.record("예상하지 않은 순위 조회")
        return []
    }
    var loadStints: @Sendable (Int, Int) async throws -> [DriverStint] = { _, _ in
        Issue.record("예상하지 않은 스틴트 조회")
        return []
    }

    func fetchRadioRecords(sessionID: Int, driverNumber: Int) async throws -> [RadioRecord] {
        try await loadRadioRecords(sessionID, driverNumber)
    }

    func fetchLaps(sessionID: Int, driverNumber: Int) async throws -> [DriverLap] {
        try await loadLaps(sessionID, driverNumber)
    }

    func fetchPositions(sessionID: Int, driverNumber: Int) async throws -> [DriverPosition] {
        try await loadPositions(sessionID, driverNumber)
    }

    func fetchStints(sessionID: Int, driverNumber: Int) async throws -> [DriverStint] {
        try await loadStints(sessionID, driverNumber)
    }
}
