//
//  OpenF1PositionDTO.swift
//  RadioLap
//

import Foundation

/// OpenF1 응답의 사용 필드를 해석하고 원본 값과 부재를 보존한다.
nonisolated struct OpenF1PositionDTO: OpenF1DriverRecordDTO {
    let sessionKey: Int
    let driverNumber: Int
    let date: Date
    let position: Int

    private enum CodingKeys: String, CodingKey {
        case sessionKey = "session_key"
        case driverNumber = "driver_number"
        case date
        case position
    }
}
