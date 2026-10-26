//
//  DriverRadioInteractor.swift
//  RadioLap
//

import Foundation

/// 조회 자료의 중복·충돌을 정리하고 기록 시각 주변의 상황을 연결한다.
/// 비동기 조회·정리는 호출자의 액터를 벗어나며 상황 연결은 호출 위치에서 동기 계산한다.
nonisolated struct DriverRadioInteractor: DriverRadioUseCase {
    private let repository: any DriverRadioRepository

    init(repository: any DriverRadioRepository) {
        self.repository = repository
    }

    @concurrent
    func fetchRadioRecords(sessionID: Int, driverNumber: Int) async throws -> [RadioRecord] {
        try await query {
            try await repository.fetchRadioRecords(sessionID: sessionID, driverNumber: driverNumber)
        } normalize: { records in
            var seen: Set<RadioRecordID> = []
            return records.filter { seen.insert($0.id).inserted }.sorted {
                if $0.recordedAt != $1.recordedAt { return $0.recordedAt < $1.recordedAt }
                return $0.recordingURL.absoluteString < $1.recordingURL.absoluteString
            }
        }
    }

    @concurrent
    func fetchLaps(sessionID: Int, driverNumber: Int) async throws -> [DriverLap] {
        try await query {
            try await repository.fetchLaps(sessionID: sessionID, driverNumber: driverNumber)
        } normalize: { records in
            var laps: [Int: DriverLap] = [:]
            for record in records {
                if let previous = laps[record.number], previous != record { throw URLError(.badServerResponse) }
                laps[record.number] = record
            }
            return Array(laps.values)
        }
    }

    @concurrent
    func fetchPositions(sessionID: Int, driverNumber: Int) async throws -> [DriverPosition] {
        try await query {
            try await repository.fetchPositions(sessionID: sessionID, driverNumber: driverNumber)
        } normalize: { records in
            var positions: [Date: DriverPosition] = [:]
            for record in records {
                if let previous = positions[record.recordedAt], previous != record { throw URLError(.badServerResponse) }
                positions[record.recordedAt] = record
            }
            return Array(positions.values)
        }
    }

    @concurrent
    func fetchStints(sessionID: Int, driverNumber: Int) async throws -> [DriverStint] {
        try await query {
            try await repository.fetchStints(sessionID: sessionID, driverNumber: driverNumber)
        } normalize: { records in
            var stints: [DriverStint] = []
            for record in records {
                let compound = record.compound?.trimmingCharacters(in: .whitespacesAndNewlines)
                let stint = DriverStint(startLap: record.startLap, endLap: record.endLap,
                                        compound: compound?.isEmpty == true ? nil : compound)
                if !stints.contains(stint) { stints.append(stint) }
            }
            return stints
        }
    }

    func resolveContext(recordedAt: Date, laps: [DriverLap]?, positions: [DriverPosition]?,
                        stints: [DriverStint]?) -> RadioContext {
        let lap = resolveLap(at: recordedAt, laps: laps)
        let position: PositionContext
        if let positions {
            if let latest = positions.filter({ $0.recordedAt <= recordedAt }).max(by: { $0.recordedAt < $1.recordedAt }) {
                position = .recorded(position: latest.position, recordedAt: latest.recordedAt)
            } else {
                position = .unavailable
            }
        } else {
            position = .notLoaded
        }
        return RadioContext(lap: lap, position: position, tyre: resolveTyre(lap: lap, stints: stints))
    }

    private func query<Value: Sendable>(load: () async throws -> [Value],
                                       normalize: ([Value]) throws -> [Value]) async throws -> [Value] {
        do {
            try Task.checkCancellation()
            let records = try await load()
            try Task.checkCancellation()
            let result = try normalize(records)
            try Task.checkCancellation()
            return result
        } catch {
            try Task.checkCancellation()
            throw error
        }
    }

    private func resolveLap(at date: Date, laps: [DriverLap]?) -> LapContext {
        guard let laps else { return .notLoaded }
        var current: [(number: Int, start: Date, end: Date)] = []
        var last: (number: Int, end: Date)?
        var lastIsConflicting = false
        for lap in laps {
            guard let start = lap.startsAt, let duration = lap.duration, duration > 0 else { continue }
            let end = start.addingTimeInterval(duration)
            guard end.timeIntervalSinceReferenceDate.isFinite else { continue }
            if start <= date, date < end { current.append((lap.number, start, end)) }
            guard end <= date else { continue }
            if let previous = last {
                if end == previous.end {
                    lastIsConflicting = true
                } else if end > previous.end {
                    last = (lap.number, end)
                    lastIsConflicting = false
                }
            } else {
                last = (lap.number, end)
            }
        }
        if current.count > 1 { return .conflicting }
        if let current = current.first {
            return .current(number: current.number, startsAt: current.start, endsAt: current.end)
        }
        if lastIsConflicting { return .conflicting }
        if let last { return .lastCompleted(number: last.number, endsAt: last.end) }
        return .unavailable
    }

    private func resolveTyre(lap: LapContext, stints: [DriverStint]?) -> TyreContext {
        let number: Int
        let isCurrent: Bool
        switch lap {
        case .current(let value, _, _): number = value; isCurrent = true
        case .lastCompleted(let value, _): number = value; isCurrent = false
        case .notLoaded, .unavailable, .conflicting: return .lapUnavailable
        }
        guard let stints else { return .stintsNotLoaded }
        var compounds: Set<String> = []
        var incomplete = false
        for stint in stints {
            guard let start = stint.startLap, let end = stint.endLap,
                  start <= end, start <= number, number <= end else { continue }
            if let compound = stint.compound { compounds.insert(compound) }
            else { incomplete = true }
        }
        if compounds.count > 1 { return .conflicting }
        if incomplete { return .incomplete }
        guard let compound = compounds.first else { return .unavailable }
        return isCurrent ? .current(compound: compound) : .lastCompleted(compound: compound)
    }
}
