//
//  DemoDriverRadioProvider.swift
//  RadioLap
//

import Foundation

/// 저장된 세션 자료에서 지원 드라이버의 기록을 제공한다.
nonisolated struct DemoDriverRadioProvider: DriverRadioRepository {
    private let supportedDriversBySession: [Int: Set<Int>]
    private let loadRadioRecords: @Sendable (Int) async throws -> Data
    private let loadLaps: @Sendable (Int) async throws -> Data
    private let loadPositions: @Sendable (Int) async throws -> Data
    private let loadStints: @Sendable (Int) async throws -> Data

    init(supportedDriversBySession: [Int: Set<Int>],
         loadRadioRecords: @escaping @Sendable (Int) async throws -> Data,
         loadLaps: @escaping @Sendable (Int) async throws -> Data,
         loadPositions: @escaping @Sendable (Int) async throws -> Data,
         loadStints: @escaping @Sendable (Int) async throws -> Data) {
        self.supportedDriversBySession = supportedDriversBySession
        self.loadRadioRecords = loadRadioRecords
        self.loadLaps = loadLaps
        self.loadPositions = loadPositions
        self.loadStints = loadStints
    }

    /// 저장된 세션 전체 원본을 사용한다. 초기화 시 파일을 읽지 않는다.
    init(bundle: Bundle) {
        self.init(
            supportedDriversBySession: [11388: [1, 3, 5, 6, 10, 11, 12, 14, 16, 18, 23, 27, 30, 31, 41, 43, 44, 55, 63, 77, 81, 87]],
            loadRadioRecords: { try Self.read("team_radio-\($0)", bundle: bundle) },
            loadLaps: { try Self.read("laps-\($0)", bundle: bundle) },
            loadPositions: { try Self.read("position-\($0)", bundle: bundle) },
            loadStints: { try Self.read("stints-\($0)", bundle: bundle) })
    }

    @concurrent
    func fetchRadioRecords(sessionID: Int, driverNumber: Int) async throws -> [RadioRecord] {
        try await records(OpenF1TeamRadioDTO.self, sessionID: sessionID, driverNumber: driverNumber, load: loadRadioRecords) { record in
            RadioRecord(recordedAt: record.date, recordingURL: record.recordingURL)
        }
    }

    @concurrent
    func fetchLaps(sessionID: Int, driverNumber: Int) async throws -> [DriverLap] {
        try await records(OpenF1LapDTO.self, sessionID: sessionID, driverNumber: driverNumber, load: loadLaps) { record in
            DriverLap(number: record.lapNumber, startsAt: record.dateStart, duration: record.lapDuration)
        }
    }

    @concurrent
    func fetchPositions(sessionID: Int, driverNumber: Int) async throws -> [DriverPosition] {
        try await records(OpenF1PositionDTO.self, sessionID: sessionID, driverNumber: driverNumber, load: loadPositions) { record in
            DriverPosition(recordedAt: record.date, position: record.position)
        }
    }

    @concurrent
    func fetchStints(sessionID: Int, driverNumber: Int) async throws -> [DriverStint] {
        try await records(OpenF1StintDTO.self, sessionID: sessionID, driverNumber: driverNumber, load: loadStints) { record in
            DriverStint(startLap: record.lapStart, endLap: record.lapEnd, compound: record.compound)
        }
    }

    private func records<Record: OpenF1DriverRecordDTO, Value: Sendable>(
        _ type: Record.Type, sessionID: Int, driverNumber: Int, load: @Sendable (Int) async throws -> Data,
        transform: (Record) -> Value
    ) async throws -> [Value] {
        do {
            try Task.checkCancellation()
            guard supportedDriversBySession[sessionID]?.contains(driverNumber) == true
            else { throw URLError(.resourceUnavailable) }
            let data = try await load(sessionID)
            try Task.checkCancellation()
            // 전체 자료의 식별자를 먼저 확인하며, 선택하지 않은 드라이버의 사용 필드는 해석하지 않는다.
            guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else { throw URLError(.badServerResponse) }
            let decoder = JSONDecoder.driverRadioResponses()
            var selected: [Data] = []
            for row in rows {
                try Task.checkCancellation()
                let rowData = try JSONSerialization.data(withJSONObject: row)
                let identity = try decoder.decode(RecordIdentity.self, from: rowData)
                guard identity.sessionKey == sessionID else { throw URLError(.badServerResponse) }
                if identity.driverNumber == driverNumber { selected.append(rowData) }
            }
            let result = try selected.map { rowData in
                try Task.checkCancellation()
                return transform(try decoder.decode(Record.self, from: rowData))
            }
            try Task.checkCancellation()
            return result
        } catch {
            try Task.checkCancellation()
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            throw error
        }
    }

    private struct RecordIdentity: Decodable {
        let sessionKey: Int
        let driverNumber: Int

        private enum CodingKeys: String, CodingKey {
            case sessionKey = "session_key"
            case driverNumber = "driver_number"
        }
    }

    private static func read(_ name: String, bundle: Bundle) throws -> Data {
        try Task.checkCancellation()
        guard let url = bundle.url(forResource: name, withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
        return try Data(contentsOf: url)
    }
}
