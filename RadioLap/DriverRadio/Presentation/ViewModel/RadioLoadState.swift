//
//  RadioLoadState.swift
//  RadioLap
//

import Foundation

/// 각 자료의 조회 상태. 정상 빈 결과와 성공 자료 미준비를 구분한다.
nonisolated enum RadioLoadState<Value: Equatable & Sendable>: Equatable, Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed
    case cancelled
}

/// 독립적으로 조회·재시도하는 자료의 종류.
nonisolated enum RadioDataKind: Sendable {
    case radio
    case laps
    case positions
    case stints
}
