//
//  RaceDetailPresentation.swift
//  RadioLap
//

import Observation

/// 선택한 레이스와 드라이버 영역의 관찰 가능한 상태·조회 동작을 제공한다.
@MainActor
protocol RaceDetailPresentation: AnyObject, Observable {
    /// 화면 수명 동안 유지하는 목록에서 선택한 레이스.
    var race: Race { get }

    /// 초기값은 idle이며, 레이스 기본 정보와 독립적으로 드라이버 영역을 표현한다.
    var state: RaceDetailState { get }

    /// 기존 요청을 취소·무효화하고 즉시 loading으로 전환해 같은 Race로 조회한다.
    /// 응답을 기다리지 않고 반환하며 마지막 유효 요청의 결과만 상태에 반영한다.
    func load()

    /// 진행 중인 요청을 취소·무효화하고 즉시 cancelled로 전환한다.
    /// 진행 중인 요청이 없으면 현재 상태를 유지하며, 취소된 요청의 늦은 응답은 반영하지 않는다.
    func cancel()
}
