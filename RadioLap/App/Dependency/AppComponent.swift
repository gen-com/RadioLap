//
//  AppComponent.swift
//  RadioLap
//

import Foundation

/// 앱에서 사용할 데이터 접근 구현을 조립한다.
@MainActor
final class AppComponent: RaceListDependency {
    let raceListRepository: any RaceListRepository

    init() {
        raceListRepository = DemoRaceListProvider(bundle: .main)
    }
}
