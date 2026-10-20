//
//  RaceListRepository.swift
//  RadioLap
//

import Foundation

/// 데이터 출처에 관계없이 종료된 결승 목록을 제공하는 계약.
///
/// 구현체는 데이터 조회·연결·변환을 담당한다. 목록 정렬과 화면 상태는 Presentation의 책임이다.
nonisolated protocol RaceListRepository: Sendable {
    /// 지정한 시즌에서 대회와 세션 모두 취소되지 않고, 종료 시각이 기준보다 이른 결승을 조회한다.
    ///
    /// 연습·예선·스프린트는 제외한다. 종료 여부는 데이터의 종료 시각으로 판단하며,
    /// 결과 확정이나 라디오 데이터 준비 완료를 보장하지 않는다.
    /// 사용자 기기의 시간대는 조회 조건에 영향을 주지 않는다.
    ///
    /// - Parameters:
    ///   - year: 조회할 시즌 연도. 첫 화면에서는 `2026`을 전달한다.
    ///   - endedBefore: 종료 여부를 판단할 절대 시각. 호출 시점의 현재 시각을 전달하며,
    ///     구현체는 현재 시각을 별도로 읽지 않는다. 종료 시각이 이 값과 같으면 제외한다.
    /// - Returns: 조건에 맞는 레이스 배열. `sessionID`는 중복되지 않으며 반환 순서는 보장하지 않는다.
    ///   정상 조회했으나 해당 결승이 없으면 빈 배열을 반환한다.
    /// - Throws: 통신 실패, 필수 데이터 해석 실패 또는 필요한 대회 정보 연결 실패에 대한 오류.
    ///   작업 취소는 `CancellationError`로 전달한다. 실패를 빈 배열로 바꾸거나,
    ///   필수 데이터가 잘못된 대상 항목을 조용히 버리지 않는다.
    func fetchRaces(
        year: Int,
        endedBefore: Date
    ) async throws -> [Race]
}
