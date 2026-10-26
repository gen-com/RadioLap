//
//  RaceListComponent.swift
//  RadioLap
//

import Foundation

/// 목록 조회 의존성을 조립하고 상세 진입에 필요한 Component를 제공한다.
@MainActor
final class RaceListComponent {
    let raceListUseCase: any RaceListUseCase
    let raceDetailComponent = RaceDetailComponent()

    init() {
        let repository = DemoRaceListProvider(bundle: .main)
        raceListUseCase = RaceListInteractor(repository: repository)
    }
}
