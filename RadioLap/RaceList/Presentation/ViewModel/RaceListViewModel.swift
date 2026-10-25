//
//  RaceListViewModel.swift
//  RadioLap
//

import Foundation
import Observation

/// 목록 조회 상태를 관리하고 유효한 요청의 결과만 반영한다.
@MainActor
@Observable
final class RaceListViewModel: RaceListPresentation {
    private(set) var state: RaceListState = .idle

    private let useCase: any RaceListUseCase
    private let now: () -> Date

    @ObservationIgnored
    private var loadingTask: Task<Void, Never>?

    /// - Parameters:
    ///   - useCase: 표시할 결승 목록을 제공한다.
    ///   - now: load 호출마다 한 번 읽는 종료 판단 기준 시각.
    init(useCase: any RaceListUseCase, now: @escaping () -> Date = Date.init) {
        self.useCase = useCase
        self.now = now
    }

    func cancel() {
        guard let task = loadingTask else { return }
        task.cancel()
        loadingTask = nil
        state = .idle
    }

    func load() {
        loadingTask?.cancel()
        state = .loading
        let endedBefore = now()
        let useCase = useCase

        loadingTask = Task { [weak self] in
            guard !Task.isCancelled else { return }

            let result: Result<[Race], any Error>
            do {
                let races = try await useCase.fetchRaces(year: 2026, endedBefore: endedBefore)
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
            state = races.isEmpty ? .empty : .content(races)
        case .failure(is CancellationError):
            state = .idle
        case .failure:
            state = .failed(message: "레이스 목록을 불러오지 못했습니다. 다시 시도해주세요.")
        }
    }
}
