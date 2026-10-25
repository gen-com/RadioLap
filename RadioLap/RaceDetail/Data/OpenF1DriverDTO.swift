//
//  OpenF1DriverDTO.swift
//  RadioLap
//

import Foundation

/// OpenF1 참가자 자료. 사용 필드를 해석하고 문자열 원문을 보존한다.
nonisolated struct OpenF1DriverDTO: Decodable, Sendable {
    let sessionKey: Int
    let driverNumber: Int
    let fullName: String
    let nameAcronym: String?
    let teamName: String?

    private enum CodingKeys: String, CodingKey {
        case sessionKey = "session_key"
        case driverNumber = "driver_number"
        case fullName = "full_name"
        case nameAcronym = "name_acronym"
        case teamName = "team_name"
    }
}
