//
//  DriverLap.swift
//  RadioLap
//

import Foundation

/// 랩 구간 구성의 근거. 불완전하거나 구간을 구성할 수 없는 값도 보존한다.
nonisolated struct DriverLap: Equatable, Sendable {
    /// 제공된 랩 번호. 별도 숫자 범위 제한을 적용하지 않는다.
    let number: Int

    /// 근사 시작 절대 시각. 원본 누락·null은 nil이다.
    let startsAt: Date?

    /// 초 단위 소요 시간. 누락·null은 nil이며 0 이하 값도 보존한다.
    let duration: TimeInterval?
}
