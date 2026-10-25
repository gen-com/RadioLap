//
//  RaceDetail.swift
//  RadioLap
//

import Foundation

/// 한 결승의 정보와 참가자 목록. 표시 순서와 화면 상태는 포함하지 않는다.
nonisolated struct RaceDetail: Equatable, Sendable {
    /// 목록에서 선택한 레이스. 기본 정보를 다시 조회하거나 정규화하지 않고 그대로 보존한다.
    let race: Race

    /// 중복 처리 후 참가자 목록. 결과 미제공 참가자도 포함하며 순서는 보장하지 않는다.
    let drivers: [RaceDriver]
}
