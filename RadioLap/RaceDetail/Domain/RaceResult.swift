//
//  RaceResult.swift
//  RadioLap
//

import Foundation

/// 제공된 결승 결과. 순위와 세 상태는 독립적이며 서로를 추론하거나 덮어쓰지 않는다.
nonisolated struct RaceResult: Equatable, Sendable {
    /// 제공된 최종 순위. 원본의 누락·null은 nil이며 숫자 범위 제한이나 임의 순위 부여 없이 보존한다.
    let position: Int?

    /// 원본 dnf. true여도 제공된 순위를 유지한다.
    let didNotFinish: Bool

    /// 원본 dns. 결과 레코드 부재에서 추론하지 않는다.
    let didNotStart: Bool

    /// 원본 dsq. 다른 상태와 함께 true일 수 있으며 하나의 상태로 축약하지 않는다.
    let isDisqualified: Bool
}
