//
//  DriverRadioComponent.swift
//  RadioLap
//

import Foundation

@MainActor
protocol DriverRadioDependency {
    var openF1Client: OpenF1Client { get }
}

/// 기능의 조회 의존성을 조립한다.
@MainActor
final class DriverRadioComponent {
    let openF1Client: OpenF1Client
    let driverRadioUseCase: any DriverRadioUseCase

    init(dependency: any DriverRadioDependency) {
        openF1Client = dependency.openF1Client
        let repository = OpenF1DriverRadioProvider(client: openF1Client)
        driverRadioUseCase = DriverRadioInteractor(repository: repository)
    }

    func newPlayback() -> any RadioPlayback {
        RadioPlayer(transport: AVPlayerRadioAudioTransport())
    }
}
