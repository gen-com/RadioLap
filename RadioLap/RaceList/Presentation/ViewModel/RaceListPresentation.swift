//
//  RaceListPresentation.swift
//  RadioLap
//

import Observation

/// 목록의 관찰 가능한 상태와 조회·취소 동작을 제공한다.
/// UseCase가 제공한 목록과 순서를 유지한다.
@MainActor
protocol RaceListPresentation: AnyObject, Observable {
    /// 외부에서 읽기만 가능하며, 초기값은 idle이다.
    var state: RaceListState { get }

    /// 모든 상태에서 이전 요청을 취소하고 즉시 loading으로 전환한다.
    /// 호출마다 기준 시각을 한 번 읽어 UseCase에 2026 시즌 조회를 요청한다.
    /// 실행 전에 취소되면 UseCase를 호출하지 않으며 마지막 유효 요청만 결과를 반영한다.
    /// 응답을 기다리지 않고 반환하며, 실패는 상태로 표현한다.
    func load()

    /// 진행 중인 요청을 취소하고 즉시 idle로 전환한다.
    /// 진행 중인 요청이 없으면 현재 상태를 유지한다.
    /// 취소된 요청의 늦은 결과는 반영하지 않으며 하위 작업의 즉시 종료를 보장하지 않는다.
    func cancel()
}
