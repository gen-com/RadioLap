//
//  RaceDetailComponent.swift
//  RadioLap
//

import Foundation

@MainActor
protocol RaceDetailDependency {
    var openF1Client: OpenF1Client { get }
}

/// 기능의 조회 의존성을 조립한다.
@MainActor
final class RaceDetailComponent: DriverRadioDependency {
    let openF1Client: OpenF1Client
    let raceDetailUseCase: any RaceDetailUseCase
    lazy var driverRadioComponent = DriverRadioComponent(dependency: self)

    init(dependency: any RaceDetailDependency) {
        openF1Client = dependency.openF1Client
        let repository = OpenF1RaceDetailProvider(client: openF1Client)
        raceDetailUseCase = RaceDetailInteractor(repository: repository)
    }
}
