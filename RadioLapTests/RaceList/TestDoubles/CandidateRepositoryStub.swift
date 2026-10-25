//
//  CandidateRepositoryStub.swift
//  RadioLapTests
//

import Foundation

/// 도메인 후보 또는 오류만 공급한다. 정제·정렬 정책과 대기 제어는 포함하지 않는다.
nonisolated struct CandidateRepositoryStub: RaceListRepository {
    let load: @Sendable (Int) async throws -> [RaceCandidate]

    func fetchRaceCandidates(year: Int) async throws -> [RaceCandidate] {
        try await load(year)
    }
}
