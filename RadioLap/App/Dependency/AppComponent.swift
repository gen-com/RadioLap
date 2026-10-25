//
//  AppComponent.swift
//  RadioLap
//

import Foundation

/// 앱에서 사용할 Repository와 UseCase 구현을 조립한다.
@MainActor
final class AppComponent: RaceListDependency {
    let raceListUseCase: any RaceListUseCase

    init() {
        let repository = DemoRaceListProvider(bundle: .main)
        raceListUseCase = RaceListInteractor(repository: repository)
    }
}
