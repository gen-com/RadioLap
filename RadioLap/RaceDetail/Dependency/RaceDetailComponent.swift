//
//  RaceDetailComponent.swift
//  RadioLap
//

import Foundation

/// 상세 화면에 필요한 조회 의존성을 조립한다.
@MainActor
final class RaceDetailComponent {
    let raceDetailUseCase: any RaceDetailUseCase

    init() {
        let repository = DemoRaceDetailProvider(
            bundle: .main, sessionResources: [11388: (drivers: "drivers", results: "session_result")]
        )
        raceDetailUseCase = RaceDetailInteractor(repository: repository)
    }
}
