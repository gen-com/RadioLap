//
//  OpenF1RaceDetailProvider.swift
//  RadioLap
//

import Foundation

/// 실제 API에서 자료를 조회하여 Repository 계약에 맞게 반환한다.
nonisolated struct OpenF1RaceDetailProvider: RaceDetailRepository {
    private let client: OpenF1Client

    init(client: OpenF1Client) {
        self.client = client
    }

    func fetchRaceDetailCandidate(sessionID: Int) async throws -> RaceDetailCandidate {
        do {
            try Task.checkCancellation()
            let query = SessionQuery(sessionKey: sessionID)
            let driversData = try await client.request(OpenF1Request(path: .drivers, query: query))
            let resultsData = try await client.request(OpenF1Request(path: .sessionResult, query: query))
            let drivers = try Self.decodeRecords(OpenF1DriverDTO.self, from: driversData)
            let results = try Self.decodeRecords(OpenF1SessionResultDTO.self, from: resultsData)
            let candidate = try mapCandidate(sessionID: sessionID, drivers: drivers, results: results)
            try Task.checkCancellation()
            return candidate
        } catch {
            try Task.checkCancellation()
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            throw error
        }
    }

    private func mapCandidate(
        sessionID: Int, drivers: [OpenF1DriverDTO], results: [OpenF1SessionResultDTO]
    ) throws -> RaceDetailCandidate {
        var driverNumbers: Set<Int> = []
        for driver in drivers {
            try Task.checkCancellation()
            guard driver.sessionKey == sessionID else { throw URLError(.badServerResponse) }
            driverNumbers.insert(driver.driverNumber)
        }
        var resultsByNumber: [Int: [RaceResult]] = [:]
        var unmatched: [RaceDetailCandidate.UnmatchedResult] = []
        for result in results {
            try Task.checkCancellation()
            guard result.sessionKey == sessionID else { throw URLError(.badServerResponse) }
            let value = RaceResult(position: result.position, didNotFinish: result.dnf,
                                   didNotStart: result.dns, isDisqualified: result.dsq)
            if driverNumbers.contains(result.driverNumber) {
                resultsByNumber[result.driverNumber, default: []].append(value)
            } else {
                unmatched.append(.init(driverNumber: result.driverNumber, result: value))
            }
        }
        let participants = try drivers.map { driver in
            try Task.checkCancellation()
            // 같은 번호의 참가자가 중복되어도 각각에 모든 결과를 연결한다.
            return RaceDetailCandidate.Driver(driverNumber: driver.driverNumber, name: driver.fullName,
                                              acronym: driver.nameAcronym, teamName: driver.teamName,
                                              results: resultsByNumber[driver.driverNumber] ?? [])
        }
        return .init(drivers: participants, unmatchedResults: unmatched)
    }

    private static func decodeRecords<Record: Decodable>(
        _ type: Record.Type, from data: Data
    ) throws -> [Record] {
        try Task.checkCancellation()
        let decoder = JSONDecoder()
        let records = try decoder.decode([Record].self, from: data)
        try Task.checkCancellation()
        return records
    }
}

private nonisolated struct SessionQuery: Encodable, Sendable {
    let sessionKey: Int

    private enum CodingKeys: String, CodingKey {
        case sessionKey = "session_key"
    }
}
