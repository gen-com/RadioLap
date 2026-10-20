//
//  RaceListDependency.swift
//  RadioLap
//

/// 목록 진입 화면이 필요로 하는 데이터 접근 계약.
@MainActor
protocol RaceListDependency {
    var raceListRepository: any RaceListRepository { get }
}
