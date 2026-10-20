//
//  RaceListViewModelProtocol.swift
//  RadioLap
//

import Observation

/// 목록의 관찰 가능한 상태와 조회·취소 동작을 제공한다.
/// 날짜 표시와 화면 이동은 View의 책임이다.
@MainActor
protocol RaceListViewModelProtocol: AnyObject, Observable {
    /// 외부에서 읽기만 가능하며, 초기값은 idle이다.
    var state: RaceListState { get }

    /// 모든 상태에서 이전 요청을 취소하고 즉시 loading으로 전환한다.
    /// 새 기준 시각으로 2026 시즌을 조회하며 마지막 유효 요청만 결과를 반영한다.
    /// 응답을 기다리지 않고 반환하며, 실패는 상태로 표현한다.
    func load()

    /// 진행 중인 요청을 취소하고 즉시 idle로 전환한다.
    /// 진행 중인 요청이 없으면 현재 상태를 유지한다.
    func cancel()
}
