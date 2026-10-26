//
//  DriverPosition.swift
//  RadioLap
//

import Foundation

/// 세션 중 한 시각에 기록된 순위. 결승 최종 결과와 구분한다.
nonisolated struct DriverPosition: Equatable, Sendable {
    /// 순위가 기록된 절대 시각.
    let recordedAt: Date

    /// 제공된 순위. 별도 숫자 범위 제한을 적용하지 않는다.
    let position: Int
}
