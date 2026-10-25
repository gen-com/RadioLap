//
//  AppComponent.swift
//  RadioLap
//

import Foundation

/// 앱에서 사용할 Repository와 UseCase 구현을 조립한다.
@MainActor
final class AppComponent: RaceListDependency, RaceDetailDependency {
    let raceListUseCase: any RaceListUseCase
    let raceDetailUseCase: any RaceDetailUseCase

    init() {
        let repository = DemoRaceListProvider(bundle: .main)
        raceListUseCase = RaceListInteractor(repository: repository)
        let detailRepository = DemoRaceDetailProvider(
            bundle: .main, sessionResources: [11388: (drivers: "drivers", results: "session_result")]
        )
        raceDetailUseCase = RaceDetailInteractor(repository: detailRepository)
    }
}
