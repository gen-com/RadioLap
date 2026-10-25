//
//  RaceListDependency.swift
//  RadioLap
//

/// 목록 진입 화면이 ViewModel에 전달할 목록 조회 의존성.
/// 구체 구현 생성과 의존성 조립은 Component가 담당한다.
@MainActor
protocol RaceListDependency {
    /// 선별·정제·정렬된 레이스 목록을 제공하는 계약.
    var raceListUseCase: any RaceListUseCase { get }
}
