//
//  OpenF1SessionDTO.swift
//  RadioLap
//

import Foundation

/// OpenF1 응답 중 레이스 목록에 필요한 필드. 미사용 필드는 디코딩하지 않는다.
nonisolated struct OpenF1SessionDTO: Decodable, Equatable, Sendable {
    /// 세션 고유 식별자.
    let sessionKey: Int
    /// 연결할 대회 식별자.
    let meetingKey: Int
    /// 세션 종류. Race만 결승이다.
    let sessionName: String
    /// 세션 시즌 연도.
    let year: Int
    /// 세션 취소 여부.
    let isCancelled: Bool
    /// 시차가 반영된 절대 시작 시각.
    let dateStart: Date
    /// 시차가 반영된 절대 종료 시각.
    let dateEnd: Date
    /// 개최 장소. 누락과 null은 nil이다.
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
}
