//
//  RaceDetailRepository.swift
//  RadioLap
//

import Foundation

/// 자료를 조회·해석·연결하여 상세 구성 전 후보를 제공한다.
nonisolated protocol RaceDetailRepository: Sendable {
    /// 요청한 세션의 자료를 연결하고 판단에 필요한 중복·부재·원문 값을 보존한다.
    ///
    /// 세션·대회 조회, 문자열 정규화와 중복 제거는 수행하지 않는다.
    /// - Parameter sessionID: 목록에서 선택한 세션 식별자. 숫자 범위를 별도로 제한하지 않는다.
    /// - Returns: 연결된 참가자·결과 후보. 배열 순서는 보장하지 않는다.
    ///   참가자·결과가 모두 비면 빈 후보를 반환하고, 참가자 없는 결과는 unmatchedResults로 보존한다.
    /// - Throws: 자료 조회·해석 또는 요청 범위·연결 키 정합성 오류.
    ///   관찰한 취소는 CancellationError로 전달하며 일반 오류의 구체 타입은 보장하지 않는다.
    func fetchRaceDetailCandidate(sessionID: Int) async throws -> RaceDetailCandidate
}
