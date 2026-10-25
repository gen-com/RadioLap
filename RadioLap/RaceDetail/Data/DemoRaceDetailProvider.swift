//
//  DemoRaceDetailProvider.swift
//  RadioLap
//

import Foundation

/// 요청 세션의 참가자·결과 저장 자료를 연결하여 정제 전 상세 후보로 변환한다.
nonisolated struct DemoRaceDetailProvider: RaceDetailRepository {
    private let loadResponses: @Sendable (Int) async throws -> (drivers: Data, results: Data)

    /// 요청 세션에 맞는 원본 자료 공급 함수를 주입한다.
    init(loadResponses: @escaping @Sendable (Int) async throws -> (drivers: Data, results: Data)) {
        self.loadResponses = loadResponses
    }

    /// 세션별 리소스 이름으로 번들의 참가자·결과 자료를 읽는다. 초기화 자체로 조회하지 않는다.
    init(bundle: Bundle, sessionResources: [Int: (drivers: String, results: String)]) {
        self.init { sessionID in
            try Task.checkCancellation()
            guard let names = sessionResources[sessionID],
                  let drivers = bundle.url(forResource: names.drivers, withExtension: "json"),
                  let results = bundle.url(forResource: names.results, withExtension: "json")
            else { throw CocoaError(.fileNoSuchFile) }
            try Task.checkCancellation()
            let driversData = try Data(contentsOf: drivers)
            try Task.checkCancellation()
            let resultsData = try Data(contentsOf: results)
            try Task.checkCancellation()
            return (driversData, resultsData)
        }
    }

    /// 요청 세션의 자료를 해석하고 중복과 연결 부재를 보존한 후보를 반환한다.
    /// - Parameter sessionID: 목록에서 선택한 세션 식별자.
    /// - Returns: 정제 전 참가자와 미연결 결과. 반환 순서는 보장하지 않는다.
    /// - Throws: 자료 읽기·해석·연결 오류 또는 CancellationError.
    func fetchRaceDetailCandidate(sessionID: Int) async throws -> RaceDetailCandidate {
        do {
            try Task.checkCancellation()
            let responses = try await loadResponses(sessionID)
            try Task.checkCancellation()
            let drivers = try Self.decodeRecords(OpenF1DriverDTO.self, from: responses.drivers)
            let results = try Self.decodeRecords(OpenF1SessionResultDTO.self, from: responses.results)
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
