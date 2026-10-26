//
//  RaceListComponent.swift
//  RadioLap
//

import Foundation

@MainActor
protocol RaceListDependency {
    var openF1Client: OpenF1Client { get }
}

/// 기능의 조회 의존성을 조립한다.
@MainActor
final class RaceListComponent: RaceDetailDependency {
    let openF1Client: OpenF1Client
    let raceListUseCase: any RaceListUseCase
    lazy var raceDetailComponent = RaceDetailComponent(dependency: self)

    init(dependency: any RaceListDependency) {
        openF1Client = dependency.openF1Client
        let repository = OpenF1RaceListProvider(client: openF1Client)
        raceListUseCase = RaceListInteractor(repository: repository)
    }
}
