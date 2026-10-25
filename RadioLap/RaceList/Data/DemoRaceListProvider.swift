//
//  DemoRaceListProvider.swift
//  RadioLap
//

import Foundation

/// 저장된 JSON 또는 주입된 자료를 정제 전 후보로 변환한다.
nonisolated struct DemoRaceListProvider: RaceListRepository {
    enum ResourceError: Error, Equatable {
        case missingFile(String)
    }

    private let loadResponses: @Sendable (Int) async throws -> (meetings: Data, sessions: Data)

    /// 요청 시즌에 맞는 원본 자료 공급 함수를 주입한다.
    init(loadResponses: @escaping @Sendable (Int) async throws -> (meetings: Data, sessions: Data)) {
        self.loadResponses = loadResponses
    }

    /// 요청 시즌과 무관하게 번들의 고정 데모 자료를 사용한다.
    init(bundle: Bundle) {
        let meetings = bundle.url(forResource: "meetings", withExtension: "json")
        let sessions = bundle.url(forResource: "sessions", withExtension: "json")
        self.init { _ in
            guard let meetings else { throw ResourceError.missingFile("meetings.json") }
            guard let sessions else { throw ResourceError.missingFile("sessions.json") }
            let meetingsData = try Data(contentsOf: meetings)
            try Task.checkCancellation()
            return (meetingsData, try Data(contentsOf: sessions))
        }
    }

    /// 요청 시즌을 자료 공급 함수에 전달하고, 응답을 연결해 정제 전 후보로 변환한다.
    func fetchRaceCandidates(year: Int) async throws -> [RaceCandidate] {
        try Task.checkCancellation()
        let responses = try await loadResponses(year)
        try Task.checkCancellation()
        let decoded = try decodeResponses(
            meetingsData: responses.meetings, sessionsData: responses.sessions
        )
        let meetingsByID = try groupMeetingsByID(decoded.meetings)
        let candidates = try mapCandidates(decoded.sessions, meetingsByID: meetingsByID)
        try Task.checkCancellation()
        return candidates
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
