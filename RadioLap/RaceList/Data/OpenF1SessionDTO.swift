//
//  OpenF1SessionDTO.swift
//  RadioLap
//

import Foundation

/// OpenF1 후보 자료. 개별 필드의 누락·해석 불가는 nil로 보존한다.
nonisolated struct OpenF1SessionDTO: Decodable, Equatable, Sendable {
    let sessionKey: Int?
    let meetingKey: Int?
    let sessionName: String?
    let year: Int?
    let isCancelled: Bool?
    let dateStart: Date?
    let dateEnd: Date?
    let location: String?

    private enum CodingKeys: String, CodingKey {
        case sessionKey = "session_key"
        case meetingKey = "meeting_key"
        case sessionName = "session_name"
        case year = "year"
        case isCancelled = "is_cancelled"
        case dateStart = "date_start"
        case dateEnd = "date_end"
        case location = "location"
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        sessionKey = try? values.decode(Int.self, forKey: .sessionKey)
        meetingKey = try? values.decode(Int.self, forKey: .meetingKey)
        sessionName = try? values.decode(String.self, forKey: .sessionName)
        year = try? values.decode(Int.self, forKey: .year)
        isCancelled = try? values.decode(Bool.self, forKey: .isCancelled)
        dateStart = try? values.decode(Date.self, forKey: .dateStart)
        dateEnd = try? values.decode(Date.self, forKey: .dateEnd)
        location = try? values.decode(String.self, forKey: .location)
    }
}
