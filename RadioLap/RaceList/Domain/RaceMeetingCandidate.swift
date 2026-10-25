//
//  RaceMeetingCandidate.swift
//  RadioLap
//

import Foundation

/// 세션 후보에 연결된 정제 전 대회 정보.
nonisolated struct RaceMeetingCandidate: Equatable, Sendable {
    /// 대회 이름. 누락·해석 불가는 nil이며 빈 문자열과 공백뿐인 이름은 그대로 보존한다.
    let name: String?

    /// 대회의 시즌 연도. 확인할 수 없으면 nil이며 세션의 시즌으로 보충하지 않는다.
    let season: Int?

    /// 대회 취소 여부. 확인할 수 없으면 nil이며 비취소로 간주하지 않는다.
    let isCancelled: Bool?
}
