//
//  OpenF1MeetingDTO.swift
//  RadioLap
//

import Foundation

/// OpenF1 응답 중 레이스 목록에 필요한 필드. 미사용 필드는 디코딩하지 않는다.
nonisolated struct OpenF1MeetingDTO: Decodable, Equatable, Sendable {
    /// 대회 고유 식별자.
    let meetingKey: Int
    /// 목록에 표시할 대회 이름.
    let meetingName: String
    /// 대회 시즌 연도.
    let year: Int
    /// 대회 취소 여부.
    let isCancelled: Bool

    private enum CodingKeys: String, CodingKey {
        case meetingKey = "meeting_key"
        case meetingName = "meeting_name"
        case year = "year"
        case isCancelled = "is_cancelled"
    }
}
