//
//  OpenF1DriverRadioProvider.swift
//  RadioLap
//

import Foundation

/// 요청 세션·드라이버의 자료를 실제 API에서 독립적으로 조회한다.
nonisolated struct OpenF1DriverRadioProvider: DriverRadioRepository {
    private let client: OpenF1Client

    init(client: OpenF1Client) {
        self.client = client
    }

    @concurrent
    func fetchRadioRecords(sessionID: Int, driverNumber: Int) async throws -> [RadioRecord] {
        try await records(OpenF1TeamRadioDTO.self, sessionID: sessionID, driverNumber: driverNumber, path: .teamRadio) { record in
            RadioRecord(recordedAt: record.date, recordingURL: record.recordingURL)
        }
    }

    @concurrent
    func fetchLaps(sessionID: Int, driverNumber: Int) async throws -> [DriverLap] {
        try await records(OpenF1LapDTO.self, sessionID: sessionID, driverNumber: driverNumber, path: .laps) { record in
            DriverLap(number: record.lapNumber, startsAt: record.dateStart, duration: record.lapDuration)
        }
    }

    @concurrent
    func fetchPositions(sessionID: Int, driverNumber: Int) async throws -> [DriverPosition] {
        try await records(OpenF1PositionDTO.self, sessionID: sessionID, driverNumber: driverNumber, path: .position) { record in
            DriverPosition(recordedAt: record.date, position: record.position)
        }
    }

    @concurrent
    func fetchStints(sessionID: Int, driverNumber: Int) async throws -> [DriverStint] {
        try await records(OpenF1StintDTO.self, sessionID: sessionID, driverNumber: driverNumber, path: .stints) { record in
            DriverStint(startLap: record.lapStart, endLap: record.lapEnd, compound: record.compound)
        }
    }

    private func records<Record: OpenF1DriverRecordDTO, Value: Sendable>(
        _ type: Record.Type, sessionID: Int, driverNumber: Int, path: OpenF1Request.Path,
        transform: (Record) -> Value
    ) async throws -> [Value] {
        do {
            try Task.checkCancellation()
            let query = DriverQuery(sessionKey: sessionID, driverNumber: driverNumber)
            let data = try await client.request(OpenF1Request(path: path, query: query))
            try Task.checkCancellation()
            let records = try JSONDecoder.driverRadioResponses().decode([Record].self, from: data)
            try Task.checkCancellation()
            let result = try records.map { record in
                try Task.checkCancellation()
                guard record.sessionKey == sessionID, record.driverNumber == driverNumber
                else { throw URLError(.badServerResponse) }
                return transform(record)
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
}

private nonisolated struct DriverQuery: Encodable, Sendable {
    let sessionKey: Int
    let driverNumber: Int

    private enum CodingKeys: String, CodingKey {
        case sessionKey = "session_key"
        case driverNumber = "driver_number"
    }
}
