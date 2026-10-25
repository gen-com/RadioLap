//
//  RaceDriverGroup.swift
//  RadioLap
//

import Foundation

/// 결과·순위 유무로 나눈 표시 그룹. 참가자 정보와 경기 상태는 그대로 유지한다.
struct RaceDriverGroup: Equatable {
    /// 그룹의 표시 순서와 안내를 결정하는 구분.
    let kind: Kind

    /// 그룹별 표시 기준으로 정렬한 참가자. 빈 그룹은 화면 상태에 포함하지 않는다.
    let drivers: [RaceDriver]

    enum Kind: Equatable {
        /// 결과와 순위가 있음. 순위 오름차순, 동률은 번호 오름차순.
        case ranked
        /// 결과는 있지만 순위가 없음. 번호 오름차순.
        case unranked
        /// 결과 레코드가 없음. 번호 오름차순.
        case resultsUnavailable
    }
}
