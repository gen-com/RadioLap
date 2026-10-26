//
//  RadioContext.swift
//  RadioLap
//

import Foundation

/// 라디오 기록 시각 주변의 상황. 실제 발화 순간의 확정된 상황을 뜻하지 않는다.
nonisolated struct RadioContext: Equatable, Sendable {
    /// 현재 구간 또는 마지막 완료 랩과 그 근거 절대 시각.
    let lap: LapContext
    /// 기록 시각 이전 또는 같은 시각의 최신 순위. 랩과 독립적이다.
    let position: PositionContext
    /// 결정된 랩에 연결한 타이어. 기준 랩과 시각은 lap을 함께 사용한다.
    let tyre: TyreContext
}

/// 시작 이상·종료 미만 구간으로 연결하며 현재 구간이 없을 때 마지막 완료 랩을 제공한다.
nonisolated enum LapContext: Equatable, Sendable {
    case current(number: Int, startsAt: Date, endsAt: Date)
    case lastCompleted(number: Int, endsAt: Date)
    case unavailable
    case conflicting
    case notLoaded
}

/// 최신 순위의 근거 시각을 보존한다. 오래됐다는 이유로 임의 제외하지 않는다.
nonisolated enum PositionContext: Equatable, Sendable {
    case recorded(position: Int, recordedAt: Date)
    case unavailable
    case notLoaded
}

/// 랩 연결 불가 → 스틴트 미준비 → 충돌 → 불완전 → 정보 없음 순으로 사유를 결정한다.
/// unavailable은 성공 자료에 적용 범위가 없음을 뜻하며 미준비와 구분한다.
nonisolated enum TyreContext: Equatable, Sendable {
    case current(compound: String)
    case lastCompleted(compound: String)
    case unavailable
    case conflicting
    case incomplete
    case lapUnavailable
    case stintsNotLoaded
}
