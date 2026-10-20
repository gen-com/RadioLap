//
//  RaceListViewModel.swift
//  RadioLap
//

import Foundation
import Observation

/// 목록 조회 상태를 관리하고 유효한 요청의 결과만 반영한다.
@MainActor
@Observable
final class RaceListViewModel: RaceListViewModelProtocol {
    /// 외부에서는 읽기만 가능한 현재 조회 상태.
    private(set) var state: RaceListState = .idle

    private let repository: any RaceListRepository
    private let now: () -> Date

    @ObservationIgnored
    private var loadingTask: Task<Void, Never>?

    /// - Parameters:
    ///   - repository: 종료된 결승을 제공하는 계약.
    ///   - now: 실행 전 취소 여부와 관계없이 load 호출마다 한 번 읽는 기준 시각.
    init(repository: any RaceListRepository, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.now = now
    }

    /// 현재 작업에 취소를 요청하고, 응답을 기다리지 않고 idle로 전환한다.
    /// 조회 작업이 없으면 현재 상태를 유지한다.
    func cancel() {
        guard let task = loadingTask else { return }
        task.cancel()
        loadingTask = nil
        state = .idle
    }

    /// 이전 작업을 취소하고 새 기준 시각으로 조회를 시작한 뒤 즉시 반환한다.
    /// 현재 상태와 관계없이 호출할 수 있으며 마지막 요청의 결과만 반영한다.
    func load() {
        loadingTask?.cancel()
        state = .loading
        let endedBefore = now()
        let repository = repository

        loadingTask = Task { [weak self] in
            guard !Task.isCancelled else { return }

            let result: Result<[Race], any Error>
            do {
                let races = try await repository.fetchRaces(year: 2026, endedBefore: endedBefore)
                result = .success(races)
            } catch {
                result = .failure(error)
            }

            // 취소된 이전 작업은 새 작업의 참조와 화면 상태를 변경하지 않는다.
            guard !Task.isCancelled, let self else { return }
            self.loadingTask = nil
            self.apply(result)
        }
    }

    private func apply(_ result: Result<[Race], any Error>) {
        switch result {
        case .success(let races):
            let sorted = races.sorted {
                if $0.startsAt == $1.startsAt { return $0.sessionID < $1.sessionID }
                return $0.startsAt > $1.startsAt
            }
            state = sorted.isEmpty ? .empty : .content(sorted)
        case .failure(is CancellationError):
            state = .idle
        case .failure:
            state = .failed(message: "레이스 목록을 불러오지 못했습니다. 다시 시도해주세요.")
        }
    }
}
