//
//  RaceDetailInteractor.swift
//  RadioLap
//

import Foundation

/// 한 레이스의 후보를 검증·정규화하고 충돌 없는 상세를 구성한다.
nonisolated struct RaceDetailInteractor: RaceDetailUseCase {
    private let repository: any RaceDetailRepository

    init(repository: any RaceDetailRepository) {
        self.repository = repository
    }

    /// 요청한 레이스의 모든 후보를 확인한 뒤 상세를 반환한다.
    /// - Parameter race: 기본 정보를 보존할 선택 레이스. sessionID를 그대로 Repository에 전달한다.
    /// - Returns: 동일 중복을 합친 상세. 참가자는 비어 있을 수 있으며 순서는 보장하지 않는다.
    /// - Throws: 미연결 결과·필수 이름 부재·값 충돌·조회 오류 또는 CancellationError.
    func fetchRaceDetail(race: Race) async throws -> RaceDetail {
        do {
            try Task.checkCancellation()
            let candidate = try await repository.fetchRaceDetailCandidate(sessionID: race.sessionID)
            try Task.checkCancellation()
            guard candidate.unmatchedResults.isEmpty else { throw DetailError.unmatchedResults }
            let drivers = try resolveDrivers(candidate.drivers)
            let detail = RaceDetail(race: race, drivers: drivers)
            try Task.checkCancellation()
            return detail
        } catch {
            try Task.checkCancellation()
            throw error
        }
    }

    private enum DetailError: Error {
        case emptyName
        case conflictingRecord(String)
        case unmatchedResults
    }

    private func resolveDrivers(_ candidates: [RaceDetailCandidate.Driver]) throws -> [RaceDriver] {
        try Task.checkCancellation()
        var driversByNumber: [Int: RaceDriver] = [:]
        var resultsByNumber: [Int: RaceResult] = [:]
        for candidate in candidates {
            try Task.checkCancellation()
            let driver = RaceDriver(driverNumber: candidate.driverNumber, name: try normalizedName(candidate.name),
                                    acronym: normalizedOptional(candidate.acronym),
                                    teamName: normalizedOptional(candidate.teamName), result: nil)
            if let previous = driversByNumber[driver.driverNumber], previous != driver {
                throw DetailError.conflictingRecord("drivers")
            }
            driversByNumber[driver.driverNumber] = driver
            // 같은 번호의 여러 레코드에 나뉜 결과도 함께 비교한다. 빈 배열은 결과를 추가하지 않는다.
            for result in candidate.results {
                try Task.checkCancellation()
                if let previous = resultsByNumber[driver.driverNumber], previous != result {
                    throw DetailError.conflictingRecord("results")
                }
                resultsByNumber[driver.driverNumber] = result
            }
        }
        var drivers: [RaceDriver] = []
        for driver in driversByNumber.values {
            try Task.checkCancellation()
            drivers.append(.init(driverNumber: driver.driverNumber, name: driver.name, acronym: driver.acronym,
                                 teamName: driver.teamName, result: resultsByNumber[driver.driverNumber]))
        }
        return drivers
    }

    private func normalizedName(_ value: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw DetailError.emptyName }
        return normalized
    }

    private func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}
