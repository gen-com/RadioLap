//
//  AppComponent.swift
//  RadioLap
//

import Foundation

/// 앱의 시작 기능에 필요한 Component를 제공한다.
@MainActor
final class AppComponent: RaceListDependency {
    let openF1Client = OpenF1Client()
    lazy var raceListComponent = RaceListComponent(dependency: self)
}
