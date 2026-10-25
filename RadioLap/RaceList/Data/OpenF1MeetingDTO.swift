//
//  OpenF1MeetingDTO.swift
//  RadioLap
//

import Foundation

/// OpenF1 후보 자료. 개별 필드의 누락·해석 불가는 nil로 보존한다.
nonisolated struct OpenF1MeetingDTO: Decodable, Equatable, Sendable {
    let meetingKey: Int?
    let meetingName: String?
    let year: Int?
    let isCancelled: Bool?

    private enum CodingKeys: String, CodingKey {
        case meetingKey = "meeting_key"
        case meetingName = "meeting_name"
        case year = "year"
        case isCancelled = "is_cancelled"
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        meetingKey = try? values.decode(Int.self, forKey: .meetingKey)
        meetingName = try? values.decode(String.self, forKey: .meetingName)
        year = try? values.decode(Int.self, forKey: .year)
        isCancelled = try? values.decode(Bool.self, forKey: .isCancelled)
    }
}
