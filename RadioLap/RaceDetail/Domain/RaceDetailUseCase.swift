//
//  RaceDetailUseCase.swift
//  RadioLap
//

import Foundation

/// 정제 전 후보를 검증·정리하여 선택한 한 레이스의 상세를 제공한다.
nonisolated protocol RaceDetailUseCase: Sendable {
    /// 입력 레이스를 보존하고 참가자의 표시 문자열 정규화·중복 처리를 수행한다.
    ///
    /// 기본 정보와 종료 여부를 다시 판단하지 않으며 화면 표시 순서와 그룹은 만들지 않는다.
    /// - Parameter race: 목록에서 선택한 레이스. 숫자 범위 검사 없이 sessionID를 Repository에 전달한다.
    /// - Returns: 입력 Race와 중복 없는 참가자. 참가자 순서는 보장하지 않는다.
    ///   결과가 없는 참가자도 유지하고, 참가자·결과가 모두 비면 빈 참가자 목록을 반환한다.
    /// - Throws: 미연결 결과·중복 충돌, 정규화 후 필수 이름 부재,
    ///   Repository의 조회 실패 또는 CancellationError. 일반 오류의 구체 타입은 보장하지 않는다.
    func fetchRaceDetail(race: Race) async throws -> RaceDetail
}
