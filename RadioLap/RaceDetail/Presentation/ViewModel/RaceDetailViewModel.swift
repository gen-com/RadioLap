//
//  RaceDetailViewModel.swift
//  RadioLap
//

import Foundation
import Observation

/// 선택한 레이스를 보존하며 유효한 조회 결과를 드라이버 표시 상태로 구성한다.
@MainActor
@Observable
final class RaceDetailViewModel: RaceDetailPresentation {
    let race: Race
    private(set) var state: RaceDetailState = .idle

    private let useCase: any RaceDetailUseCase

    @ObservationIgnored
    private var loadingTask: Task<Void, Never>?

    init(race: Race, useCase: any RaceDetailUseCase) {
        self.race = race
        self.useCase = useCase
    }

    func load() {
        loadingTask?.cancel()
        state = .loading
        let race = race
        let useCase = useCase

        loadingTask = Task { [weak self] in
            guard !Task.isCancelled else { return }

            let result: Result<RaceDetail, any Error>
            do {
                result = .success(try await useCase.fetchRaceDetail(race: race))
            } catch {
                result = .failure(error)
            }

            // 취소된 이전 작업은 현재 요청의 참조와 상태를 변경하지 않는다.
            guard !Task.isCancelled, let self else { return }
            self.loadingTask = nil
            self.apply(result)
        }
    }

    func cancel() {
        guard let task = loadingTask else { return }
        task.cancel()
        loadingTask = nil
        state = .cancelled
    }

    private func apply(_ result: Result<RaceDetail, any Error>) {
        switch result {
        case .success(let detail):
            state = detail.drivers.isEmpty ? .empty : .content(groupDrivers(detail.drivers))
        case .failure(is CancellationError):
            state = .cancelled
        case .failure:
            state = .failed
        }
    }

    private func groupDrivers(_ drivers: [RaceDriver]) -> [RaceDriverGroup] {
        var ranked: [RaceDriver] = []
        var unranked: [RaceDriver] = []
        var unavailable: [RaceDriver] = []
        for driver in drivers {
            guard let result = driver.result else {
                unavailable.append(driver)
                continue
            }
            if result.position != nil {
                ranked.append(driver)
            } else {
                unranked.append(driver)
            }
        }

        ranked.sort { lhs, rhs in
            if let left = lhs.result?.position, let right = rhs.result?.position, left != right {
                return left < right
            }
            return lhs.driverNumber < rhs.driverNumber
        }
        unranked.sort { $0.driverNumber < $1.driverNumber }
        unavailable.sort { $0.driverNumber < $1.driverNumber }

        return [RaceDriverGroup(kind: .ranked, drivers: ranked),
                RaceDriverGroup(kind: .unranked, drivers: unranked),
                RaceDriverGroup(kind: .resultsUnavailable, drivers: unavailable)]
            .filter { !$0.drivers.isEmpty }
    }
}
