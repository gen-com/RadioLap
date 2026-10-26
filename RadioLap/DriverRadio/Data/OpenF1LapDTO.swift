//
//  OpenF1LapDTO.swift
//  RadioLap
//

import Foundation

/// OpenF1 응답의 사용 필드를 해석하고 원본 값과 부재를 보존한다.
nonisolated struct OpenF1LapDTO: OpenF1DriverRecordDTO {
    let sessionKey: Int
    let driverNumber: Int
    let lapNumber: Int
    let dateStart: Date?
    let lapDuration: TimeInterval?

    private enum CodingKeys: String, CodingKey {
        case sessionKey = "session_key"
        case driverNumber = "driver_number"
        case lapNumber = "lap_number"
        case dateStart = "date_start"
        case lapDuration = "lap_duration"
    }

}
