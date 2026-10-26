//
//  OpenF1RaceListProvider.swift
//  RadioLap
//

import Foundation

/// 실제 API에서 자료를 조회하여 Repository 계약에 맞게 반환한다.
nonisolated struct OpenF1RaceListProvider: RaceListRepository {
    private let client: OpenF1Client

    init(client: OpenF1Client) {
        self.client = client
    }

    func fetchRaceCandidates(year: Int) async throws -> [RaceCandidate] {
        do {
            try Task.checkCancellation()
            let meetings = try await client.request(OpenF1Request(path: .meetings, query: MeetingsQuery(year: year)))
            let sessions = try await client.request(OpenF1Request(
                path: .sessions, query: SessionsQuery(year: year, sessionName: "Race")
            ))
            try Task.checkCancellation()
            let decoded = try decodeResponses(meetingsData: meetings, sessionsData: sessions)
            let meetingsByID = try groupMeetingsByID(decoded.meetings)
            let candidates = try mapCandidates(decoded.sessions, meetingsByID: meetingsByID)
            try Task.checkCancellation()
            return candidates
        } catch {
            try Task.checkCancellation()
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            throw error
        }
    }

    private func decodeResponses(
        meetingsData: Data, sessionsData: Data
    ) throws -> (meetings: [OpenF1MeetingDTO], sessions: [OpenF1SessionDTO]) {
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
        let meetings = try decoder.decode([OpenF1MeetingDTO].self, from: meetingsData)
        let sessions = try decoder.decode([OpenF1SessionDTO].self, from: sessionsData)
        return (meetings, sessions)
    }

    /// 같은 연결 키의 대회 정보를 모두 보존한다.
    private func groupMeetingsByID(_ meetings: [OpenF1MeetingDTO]) throws -> [Int: [RaceMeetingCandidate]] {
        var meetingsByID: [Int: [RaceMeetingCandidate]] = [:]
        for meeting in meetings {
            try Task.checkCancellation()
            guard let key = meeting.meetingKey else { continue }
            meetingsByID[key, default: []].append(RaceMeetingCandidate(
                name: meeting.meetingName, season: meeting.year, isCancelled: meeting.isCancelled
            ))
        }
        return meetingsByID
    }

    /// 대회 연결이 없거나 정보가 불완전한 세션도 후보로 보존한다.
    private func mapCandidates(
        _ sessions: [OpenF1SessionDTO], meetingsByID: [Int: [RaceMeetingCandidate]]
    ) throws -> [RaceCandidate] {
        var candidates: [RaceCandidate] = []
        for session in sessions {
            try Task.checkCancellation()
            candidates.append(RaceCandidate(
                sessionID: session.sessionKey, season: session.year,
                kind: sessionKind(session.sessionName), isCancelled: session.isCancelled,
                startsAt: session.dateStart, endsAt: session.dateEnd,
                location: session.location == "" ? nil : session.location,
                linkedMeetings: session.meetingKey.flatMap { meetingsByID[$0] } ?? []
            ))
        }
        return candidates
    }

    private func sessionKind(_ name: String?) -> RaceSessionKind? {
        switch name {
        case "Race": .race
        case "Practice 1", "Practice 2", "Practice 3", "Qualifying", "Sprint",
             "Sprint Qualifying", "Sprint Shootout": .other
        default: nil
        }
    }
}

private nonisolated struct MeetingsQuery: Encodable, Sendable {
    let year: Int
}

private nonisolated struct SessionsQuery: Encodable, Sendable {
    let year: Int
    let sessionName: String

    private enum CodingKeys: String, CodingKey {
        case year
        case sessionName = "session_name"
    }
}
