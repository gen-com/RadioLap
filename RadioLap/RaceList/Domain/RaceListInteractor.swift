//
//  RaceListInteractor.swift
//  RadioLap
//

import Foundation

/// 후보를 선별·정제하여 종료된 결승을 최신순으로 제공한다.
nonisolated struct RaceListInteractor: RaceListUseCase {
    private let repository: any RaceListRepository

    init(repository: any RaceListRepository) {
        self.repository = repository
    }

    func fetchRaces(year: Int, endedBefore: Date) async throws -> [Race] {
        try Task.checkCancellation()
        let candidates = try await repository.fetchRaceCandidates(year: year)
        try Task.checkCancellation()

        var groups: [Int: [RaceCandidate]] = [:]
        for candidate in candidates {
            try Task.checkCancellation()
            guard let id = candidate.sessionID else { continue }
            groups[id, default: []].append(candidate)
        }

        var races: [Race] = []
        for (id, group) in groups {
            try Task.checkCancellation()
            guard let race = try selectRace(id: id, candidates: group, year: year, endedBefore: endedBefore)
            else { continue }
            races.append(race)
        }

        let sorted = try races.sorted { lhs, rhs in
            try Task.checkCancellation()
            if lhs.startsAt == rhs.startsAt { return lhs.sessionID < rhs.sessionID }
            return lhs.startsAt > rhs.startsAt
        }
        try Task.checkCancellation()
        return sorted
    }

    private func selectRace(
        id: Int, candidates: [RaceCandidate], year: Int, endedBefore: Date
    ) throws -> Race? {
        var meetings: [RaceMeetingCandidate] = []
        for candidate in candidates {
            try Task.checkCancellation()
            meetings.append(contentsOf: candidate.linkedMeetings)
        }

        // 불완전하거나 표시 대상이 아닌 후보도 포함해, 확인 가능한 충돌을 제외보다 먼저 검사한다.
        guard try !hasConflict(candidates.map(\.season)),
              try !hasConflict(candidates.map(\.kind)),
              try !hasConflict(candidates.map(\.isCancelled)),
              try !hasConflict(candidates.map(\.startsAt)),
              try !hasConflict(candidates.map(\.endsAt)),
              try !hasConflict(meetings.map { usableName($0.name) }),
              try !hasConflict(meetings.map(\.season)),
              try !hasConflict(meetings.map(\.isCancelled))
        else { return nil }

        let locations = candidates.compactMap(\.location)
        let location = try hasConflict(locations.map(Optional.some)) ? nil : locations.first

        // 원래 후보·대회 연결을 유지하고 다른 후보에서 필수 값을 보충하지 않는다.
        for candidate in candidates {
            try Task.checkCancellation()
            guard candidate.season == year, candidate.kind == .race, candidate.isCancelled == false,
                  let start = candidate.startsAt, let end = candidate.endsAt,
                  end > start, end < endedBefore
            else { continue }

            for meeting in candidate.linkedMeetings {
                try Task.checkCancellation()
                guard meeting.season == year, meeting.isCancelled == false,
                      let name = usableName(meeting.name)
                else { continue }
                return Race(sessionID: id, name: name, startsAt: start, location: location)
            }
        }
        return nil
    }

    private func usableName(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }

    /// nil은 정보 부족으로 보고, 서로 다른 확인 가능한 값이 있을 때만 충돌로 판단한다.
    private func hasConflict<Value: Equatable>(_ values: [Value?]) throws -> Bool {
        var first: Value?
        for value in values {
            try Task.checkCancellation()
            guard let value else { continue }
            if let first, first != value { return true }
            first = value
        }
        return false
    }
}
