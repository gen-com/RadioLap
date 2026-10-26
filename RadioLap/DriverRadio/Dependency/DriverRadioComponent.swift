//
//  DriverRadioComponent.swift
//  RadioLap
//

import Foundation

/// 조회 의존성을 조립하고 각 화면이 전용 재생 객체를 만들 수 있게 한다.
@MainActor
final class DriverRadioComponent {
    let driverRadioUseCase: any DriverRadioUseCase

    init() {
        driverRadioUseCase = DriverRadioInteractor(repository: DemoDriverRadioProvider(bundle: .main))
    }

    func newPlayback() -> any RadioPlayback {
        RadioPlayer(transport: AVPlayerRadioAudioTransport())
    }
}
