//
//  RaceDetailComponent.swift
//  RadioLap
//

import Foundation

/// 상세 조회 의존성을 조립하고 라디오 진입에 필요한 Component를 제공한다.
@MainActor
final class RaceDetailComponent {
    let raceDetailUseCase: any RaceDetailUseCase
    let driverRadioComponent = DriverRadioComponent()

    init() {
        let repository = DemoRaceDetailProvider(
            bundle: .main, sessionResources: [11388: (drivers: "drivers", results: "session_result")]
        )
        raceDetailUseCase = RaceDetailInteractor(repository: repository)
    }
}
