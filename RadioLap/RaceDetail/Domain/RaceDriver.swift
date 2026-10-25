//
//  RaceDriver.swift
//  RadioLap
//

import Foundation

/// 특정 세션의 참가자 정보. 영구적인 드라이버 프로필을 나타내지 않는다.
nonisolated struct RaceDriver: Identifiable, Equatable, Sendable {
    /// 제공된 드라이버 번호. 세션 내에서 유일하며 기능 간 식별에는 부모 sessionID도 함께 사용한다.
    let driverNumber: Int

    /// full_name의 앞뒤 공백을 정리한 필수 이름. 대소문자는 보존한다.
    let name: String

    /// 이름 약칭. 누락·null 또는 정규화 후 빈 값은 nil이며 길이를 강제하지 않는다.
    let acronym: String?

    /// 해당 세션의 팀 이름. 누락·null 또는 정규화 후 빈 값은 nil이다.
    let teamName: String?

    /// 결과 레코드가 없으면 nil. 결과는 있지만 순위가 없는 경우와 구분한다.
    let result: RaceResult?

    /// 한 RaceDetail의 참가자 목록 안에서만 유일한 식별자.
    var id: Int { driverNumber }
}
