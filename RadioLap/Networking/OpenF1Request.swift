//
//  OpenF1Request.swift
//  RadioLap
//

import Foundation

/// URLRequest 조립에 필요한 경로·조회 조건·본문을 표현한다.
nonisolated struct OpenF1Request: Sendable {
    enum Path: String, Sendable {
        case meetings
        case sessions
        case drivers
        case sessionResult = "session_result"
        case teamRadio = "team_radio"
        case laps
        case position
        case stints
    }

    static let scheme = "https"
    static let host = "api.openf1.org"

    let path: Path
    var method: HTTPMethod = .get
    var headers: [String: String] = ["Accept": "application/json"]
    var query: (any Encodable & Sendable)?
    var body: (any Encodable & Sendable)?
}
