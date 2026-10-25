//
//  RaceDetailRepositoryStub.swift
//  RadioLapTests
//

import Foundation

/// 후보나 오류를 공급한다. 상세 정제 정책은 수행하지 않는다.
nonisolated struct RaceDetailRepositoryStub: RaceDetailRepository {
    let load: @Sendable (Int) async throws -> RaceDetailCandidate

    func fetchRaceDetailCandidate(sessionID: Int) async throws -> RaceDetailCandidate {
        try await load(sessionID)
    }
}
