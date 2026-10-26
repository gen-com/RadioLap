//
//  DemoDriverRadioProvider.swift
//  RadioLap
//

import Foundation
import CoreFoundation

/// 세션 전체 자료의 범위를 확인한 뒤 요청 드라이버의 사용 필드만 해석한다.
/// 파일 읽기·해석은 호출자의 액터를 벗어나 수행하며 같은 작업의 취소를 유지한다.
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
        try await records(sessionID: sessionID, driverNumber: driverNumber, load: loadRadioRecords) { record in
            let address = try Self.string(record["recording_url"])
            guard address == address.trimmingCharacters(in: .whitespacesAndNewlines),
                  let url = URL(string: address, encodingInvalidCharacters: false),
                  ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  let host = url.host, !host.isEmpty else { throw URLError(.badServerResponse) }
            return RadioRecord(recordedAt: try Self.date(record["date"]), recordingURL: url)
        }
    }

    @concurrent
    func fetchLaps(sessionID: Int, driverNumber: Int) async throws -> [DriverLap] {
        try await records(sessionID: sessionID, driverNumber: driverNumber, load: loadLaps) { record in
            DriverLap(number: try Self.integer(record["lap_number"]),
                      startsAt: try Self.optional(record["date_start"], decode: Self.date),
                      duration: try Self.optional(record["lap_duration"], decode: Self.duration))
        }
    }

    @concurrent
    func fetchPositions(sessionID: Int, driverNumber: Int) async throws -> [DriverPosition] {
        try await records(sessionID: sessionID, driverNumber: driverNumber, load: loadPositions) { record in
            DriverPosition(recordedAt: try Self.date(record["date"]), position: try Self.integer(record["position"]))
        }
    }

    @concurrent
    func fetchStints(sessionID: Int, driverNumber: Int) async throws -> [DriverStint] {
        try await records(sessionID: sessionID, driverNumber: driverNumber, load: loadStints) { record in
            DriverStint(startLap: try Self.optional(record["lap_start"], decode: Self.integer),
                        endLap: try Self.optional(record["lap_end"], decode: Self.integer),
                        compound: try Self.optional(record["compound"], decode: Self.string))
        }
    }

    private func records<Value: Sendable>(
        sessionID: Int, driverNumber: Int, load: @Sendable (Int) async throws -> Data,
        transform: ([String: Any]) throws -> Value
    ) async throws -> [Value] {
        do {
            try Task.checkCancellation()
            guard supportedDriversBySession[sessionID]?.contains(driverNumber) == true
            else { throw URLError(.resourceUnavailable) }
            let data = try await load(sessionID)
            try Task.checkCancellation()
            guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else { throw URLError(.badServerResponse) }
            var selected: [[String: Any]] = []
            for row in rows {
                guard try Self.integer(row["session_key"]) == sessionID else { throw URLError(.badServerResponse) }
                let number = try Self.integer(row["driver_number"])
                if number == driverNumber { selected.append(row) }
            }
            // 선택하지 않은 드라이버도 구조·식별자·세션은 먼저 검증한다.
            let result = try selected.map(transform)
            try Task.checkCancellation()
            return result
        } catch {
            try Task.checkCancellation()
            throw error
        }
    }

    private static func read(_ name: String, bundle: Bundle) throws -> Data {
        try Task.checkCancellation()
        guard let url = bundle.url(forResource: name, withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
        return try Data(contentsOf: url)
    }

    private static func optional<Value>(_ value: Any?, decode: (Any?) throws -> Value) throws -> Value? {
        guard let value, !(value is NSNull) else { return nil }
        return try decode(value)
    }

    private static func number(_ value: Any?) throws -> NSNumber {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID()
        else { throw URLError(.badServerResponse) }
        return number
    }

    private static func integer(_ value: Any?) throws -> Int {
        let number = try number(value)
        var decimal = number.decimalValue
        var rounded = Decimal()
        NSDecimalRound(&rounded, &decimal, 0, .plain)
        guard decimal == rounded, decimal >= Decimal(Int.min), decimal <= Decimal(Int.max)
        else { throw URLError(.badServerResponse) }
        return NSDecimalNumber(decimal: decimal).intValue
    }

    private static func duration(_ value: Any?) throws -> TimeInterval {
        let result = try number(value).doubleValue
        guard result.isFinite else { throw URLError(.badServerResponse) }
        return result
    }

    private static func string(_ value: Any?) throws -> String {
        guard let value = value as? String else { throw URLError(.badServerResponse) }
        return value
    }

    private static func date(_ value: Any?) throws -> Date {
        let text = try string(value)
        guard text.range(of: #"(?:Z|[+-]\d{2}:?\d{2})$"#, options: .regularExpression) != nil
        else { throw URLError(.badServerResponse) }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let result = formatter.date(from: text) { return result }
        formatter.formatOptions = [.withInternetDateTime]
        guard let result = formatter.date(from: text) else { throw URLError(.badServerResponse) }
        return result
    }
}
