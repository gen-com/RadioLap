//
//  RaceListResponseMapper.swift
//  RadioLap
//

import Foundation

/// 파일과 네트워크에 의존하지 않고 OpenF1 응답을 레이스 목록으로 변환한다.
nonisolated struct RaceListResponseMapper: Sendable {
    enum DataError: Error, Equatable {
        case conflictingMeeting(Int)
        case conflictingSession(Int)
        case missingMeeting(Int)
        case invalidMeeting(Int)
        case invalidSession(Int)
    }
    
    private let decoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: text)
            else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "시차를 포함한 ISO 8601 날짜가 필요합니다.") }
            return date
        }
        return decoder
    }()

    /// JSON을 해석한다. 필수 필드 누락·타입 오류·날짜 오류는 DecodingError로 전달한다.
    /// - Parameters:
    ///   - meetingsData: 대회 JSON 배열의 원본 바이트.
    ///   - sessionsData: 세션 JSON 배열의 원본 바이트.
    ///   - year: 조회 시즌.
    ///   - endedBefore: 종료 시각의 상한. 동일 시각은 제외한다.
    /// - Returns: 조건을 만족하는 중복 없는 레이스. 순서는 보장하지 않는다.
    /// - Throws: 디코딩·연결·중복 충돌 오류 또는 CancellationError.
    func races(
        meetingsData: Data,
        sessionsData: Data,
        year: Int,
        endedBefore: Date
    ) throws -> [Race] {
        let (meetings, sessions) = try decodeResponses(meetingsData, sessionsData)
        let meetingsByID = Dictionary(grouping: meetings, by: \.meetingKey)
        let sessionsByID = Dictionary(grouping: sessions, by: \.sessionKey)
        var races: [Race] = []
        for group in sessionsByID.values {
            try Task.checkCancellation()
            guard let race = try mapRace(group, meetingsByID: meetingsByID,
                                         year: year, endedBefore: endedBefore)
            else { continue }
            races.append(race)
        }
        try Task.checkCancellation()
        return races
    }

    private func decodeResponses(
        _ meetingsData: Data,
        _ sessionsData: Data
    ) throws
        -> ([OpenF1MeetingDTO], [OpenF1SessionDTO]) {
        let meetings = try decoder.decode([OpenF1MeetingDTO].self, from: meetingsData)
        try Task.checkCancellation()
        let sessions = try decoder.decode([OpenF1SessionDTO].self, from: sessionsData)
        try Task.checkCancellation()
        return (meetings, sessions)
    }

    private func isCandidate(
        _ session: OpenF1SessionDTO,
        year: Int,
        endedBefore: Date
    ) -> Bool {
        session.year == year && session.sessionName == "Race" &&
        !session.isCancelled && session.dateEnd < endedBefore
    }

    /// 같은 세션 ID의 조회 조건·대회 연결·내용을 확인해 최대 한 건을 반환한다.
    private func mapRace(
        _ sessions: [OpenF1SessionDTO],
        meetingsByID: [Int: [OpenF1MeetingDTO]],
        year: Int,
        endedBefore: Date
    ) throws -> Race? {
        let candidates = sessions.filter { isCandidate($0, year: year, endedBefore: endedBefore) }
        guard let session = candidates.first else { return nil }
        guard candidates.count == sessions.count
        else { throw DataError.conflictingSession(session.sessionKey) }

        let meeting = try linkedMeeting(for: session.meetingKey, in: meetingsByID)
        for candidate in candidates.dropFirst() {
            try Task.checkCancellation()
            let otherMeeting = try linkedMeeting(for: candidate.meetingKey, in: meetingsByID)
            // 같은 세션이 서로 다른 대회를 가리켜 표시 여부가 달라지는 경우도 충돌이다.
            guard otherMeeting.isCancelled == meeting.isCancelled
            else { throw DataError.conflictingSession(session.sessionKey) }
        }
        guard !meeting.isCancelled else { return nil }

        // 모두 제외되는 중복은 무시하고, 표시할 세션의 내용만 비교한다.
        guard candidates.allSatisfy({ $0 == session })
        else { throw DataError.conflictingSession(session.sessionKey) }
        try validate(session, meeting: meeting, year: year)
        return Race(
            sessionID: session.sessionKey,
            name: meeting.meetingName,
            startsAt: session.dateStart,
            location: session.location == "" ? nil : session.location
        )
    }

    private func linkedMeeting(
        for meetingID: Int,
        in meetingsByID: [Int: [OpenF1MeetingDTO]]
    ) throws -> OpenF1MeetingDTO {
        guard let matches = meetingsByID[meetingID], let meeting = matches.first
        else { throw DataError.missingMeeting(meetingID) }
        guard matches.allSatisfy({ $0.isCancelled == meeting.isCancelled })
        else { throw DataError.conflictingMeeting(meetingID) }
        guard !meeting.isCancelled else { return meeting }
        guard matches.allSatisfy({ $0 == meeting })
        else { throw DataError.conflictingMeeting(meetingID) }
        return meeting
    }

    private func validate(
        _ session: OpenF1SessionDTO,
        meeting: OpenF1MeetingDTO,
        year: Int
    ) throws {
        guard meeting.year == year,
              !meeting.meetingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw DataError.invalidMeeting(meeting.meetingKey) }
        
        guard session.dateEnd > session.dateStart
        else { throw DataError.invalidSession(session.sessionKey) }
    }
}
