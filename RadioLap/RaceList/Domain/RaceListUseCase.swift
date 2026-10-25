//
//  RaceListUseCase.swift
//  RadioLap
//

import Foundation

/// Repository의 후보를 선별·정제하여 최신순 결승 목록을 제공하는 계약.
nonisolated protocol RaceListUseCase: Sendable {
    /// 지정한 시즌에서 대회와 세션이 취소되지 않고 종료 시각이 기준보다 이른 결승을 조회한다.
    ///
    /// 같은 식별자의 충돌을 선별 전에 검사하며, 필수 정보·조회 자격이 충돌하면 제외한다.
    /// 장소만 충돌하면 nil로 반환하고, 서로 다른 후보의 필수 값을 합치지 않는다.
    /// 정보 누락·잘못된 시각 관계로 인한 후보 제외는 전체 조회 실패로 처리하지 않는다.
    /// 결과·라디오 준비 여부는 포함 조건으로 사용하지 않는다.
    ///
    /// - Parameters:
    ///   - year: Repository에 요청하고 최종 반환 대상에도 적용할 시즌 연도.
    ///   - endedBefore: 종료 판단 기준인 절대 시각. 이 값과 같은 시각에 종료한 결승은 제외하며,
    ///     현재 시각을 별도로 읽지 않는다.
    /// - Returns: sessionID가 중복되지 않는 레이스 배열.
    ///   시작 시각 내림차순, 동률이면 sessionID 오름차순이다.
    ///   후보가 없거나 모든 후보가 제외되면 정상 빈 배열을 반환한다.
    /// - Throws: Repository 오류를 그대로 전달한다. 취소는 Repository와 정제·정렬에 전파하고
    ///   `CancellationError`로 전달하며, 하위 작업의 즉시 종료는 보장하지 않는다.
    func fetchRaces(
        year: Int,
        endedBefore: Date
    ) async throws -> [Race]
}
