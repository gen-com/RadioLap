//
//  RaceDetailDependency.swift
//  RadioLap
//

import Foundation

/// 상세 진입 화면이 ViewModel에 전달할 조회 의존성. 구체 구현은 Component에서 조립한다.
@MainActor
protocol RaceDetailDependency {
    var raceDetailUseCase: any RaceDetailUseCase { get }
}
