//
//  RaceDetailCandidate.swift
//  RadioLap
//

import Foundation

/// 한 세션의 자료를 연결한 정제 전 후보. 중복과 연결 부재를 보존한다.
nonisolated struct RaceDetailCandidate: Equatable, Sendable {
    /// 해당 세션의 참가자 레코드들. 같은 번호의 중복과 원문 문자열을 보존한다.
    let drivers: [Driver]

    /// 참가자에 연결되지 않은 결과. 자료 정합성을 판단할 수 있도록 버리지 않는다.
    let unmatchedResults: [UnmatchedResult]

    /// 참가자와 연결된 결과. 결과 레코드 부재와 순위 부재를 구분한다.
    nonisolated struct Driver: Equatable, Sendable {
        /// 해당 세션의 0 이상 드라이버 번호. 후보에서는 중복될 수 있다.
        let driverNumber: Int
        /// 필수 드라이버 이름 원문. 정규화는 아직 수행하지 않는다.
        let name: String
        /// 약칭 원문. 누락·null은 nil이며 빈 값과 공백은 유지한다.
        let acronym: String?
        /// 해당 세션의 팀 이름 원문. 누락·null은 nil이다.
        let teamName: String?
        /// 세션과 번호로 연결된 모든 결과. 빈 배열은 결과 미제공을 뜻한다.
        let results: [RaceResult]
    }

    /// 대응 참가자가 없는 결과 레코드.
    nonisolated struct UnmatchedResult: Equatable, Sendable {
        /// 결과에 기록된 해당 세션의 드라이버 번호.
        let driverNumber: Int
        /// 순위와 독립적인 경기 상태를 보존한 결과.
        let result: RaceResult
    }
}
