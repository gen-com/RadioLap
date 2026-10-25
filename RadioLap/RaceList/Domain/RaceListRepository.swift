//
//  RaceListRepository.swift
//  RadioLap
//

import Foundation

/// 외부 자료를 조회·해석·연결하여 정제 전 후보를 제공한다.
/// 목록의 선별·정제·정렬은 UseCase가 담당한다.
nonisolated protocol RaceListRepository: Sendable {
    /// 지정한 시즌의 자료를 요청하여 정보 누락과 중복·충돌을 보존한 후보를 제공한다.
    ///
    /// 대회 연결이 없어도 후보를 유지하며 연결된 모든 대회 정보를 전달한다.
    /// 이름·시각의 개별 문제로 후보를 버리거나 조회 전체를 실패시키지 않는다.
    /// 종료 여부를 판단하거나 결과·라디오 자료를 요청하지 않는다.
    ///
    /// - Parameter year: 자료를 요청할 시즌 연도. 후보의 최종 시즌 선별은 UseCase가 담당한다.
    /// - Returns: 정제 전 후보 배열. 중복을 허용하고 반환 순서를 보장하지 않는다.
    ///   조회에 성공했으나 제공할 후보가 없으면 빈 배열을 반환한다.
    /// - Throws: 통신·HTTP 오류, 응답 전체 해석 실패, 파일·번들 리소스 누락 또는 읽기 실패.
    ///   작업 취소는 `CancellationError`로 전달하며 전체 실패를 빈 배열로 바꾸지 않는다.
    func fetchRaceCandidates(year: Int) async throws -> [RaceCandidate]
}
