//
//  OpenF1SessionResultDTO.swift
//  RadioLap
//

import Foundation

/// OpenF1 세션 결과 자료. 순위 부재와 독립적인 경기 상태를 보존한다.
nonisolated struct OpenF1SessionResultDTO: Decodable, Sendable {
    let sessionKey: Int
    let driverNumber: Int
    let position: Int?
    let dnf: Bool
    let dns: Bool
    let dsq: Bool

    private enum CodingKeys: String, CodingKey {
        case sessionKey = "session_key"
        case driverNumber = "driver_number"
        case position, dnf, dns, dsq
    }
}
