//
//  RaceCandidate.swift
//  RadioLap
//

import Foundation

/// 정보 누락과 중복·충돌을 보존한 정제 전 세션 후보.
/// 목록 표시 여부는 UseCase가 판단한다.
nonisolated struct RaceCandidate: Equatable, Sendable {
    /// 결승 식별과 중복 판단에 사용하는 세션 식별자. 확인할 수 없으면 nil이다.
    let sessionID: Int?

    /// 세션의 시즌 연도. 확인할 수 없으면 nil이며 요청 시즌으로 보충하지 않는다.
    let season: Int?

    /// 확인된 세션 종류. 누락되거나 판별할 수 없으면 nil이다.
    let kind: RaceSessionKind?

    /// 세션 취소 여부. 확인할 수 없으면 nil이며 비취소로 간주하지 않는다.
    let isCancelled: Bool?

    /// 세션 시작 절대 시각. 누락·해석 불가는 nil이며 기기 시간대에 영향을 받지 않는다.
    let startsAt: Date?

    /// 세션 종료 절대 시각. 누락·해석 불가는 nil이다.
    /// 시작 시각보다 이르거나 같아도 원래 값을 보존한다.
    let endsAt: Date?

    /// 세션의 장소. 누락·null·빈 문자열은 nil로 정규화한다.
    let location: String?

    /// 해당 세션에 연결된 모든 대회 정보. 연결이 없으면 빈 배열이며 중복·충돌도 보존한다.
    let linkedMeetings: [RaceMeetingCandidate]
}
