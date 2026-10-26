//
//  DriverRadioUseCase.swift
//  RadioLap
//

import Foundation

/// 네 자료를 독립적으로 조회·정리하고 라디오 기록 시각에 상황을 연결한다.
/// 조회는 세션·드라이버 식별자를 그대로 전달하며 실패를 빈 성공으로 바꾸지 않는다.
/// 조회 전·Repository 반환 후·정리 결과 반환 전에 취소를 확인하고,
/// 일반 오류 전달 직전 관찰한 취소도 CancellationError로 전달한다.
nonisolated protocol DriverRadioUseCase: Sendable {
    /// 기록 시각·URL 문자열이 같은 중복을 합치고 시각순·동시각 URL 문자열순으로 반환한다.
    func fetchRadioRecords(sessionID: Int, driverNumber: Int) async throws -> [RadioRecord]

    /// 같은 번호의 동일 자료를 합친다. 시작 시각·소요 시간의 충돌은 조회 전체 실패다.
    /// 불완전한 값은 보존하며 반환 순서는 보장하지 않는다.
    func fetchLaps(sessionID: Int, driverNumber: Int) async throws -> [DriverLap]

    /// 같은 시각·순위 중복을 합친다. 같은 시각의 다른 순위는 조회 전체 실패다.
    /// 반환 순서는 보장하지 않는다.
    func fetchPositions(sessionID: Int, driverNumber: Int) async throws -> [DriverPosition]

    /// 컴파운드 앞뒤 공백과 동일 중복을 정리한다. 공백뿐인 컴파운드는 nil이다.
    /// 불완전하거나 겹치는 범위를 보존하며 반환 순서는 보장하지 않는다.
    func fetchStints(sessionID: Int, driverNumber: Int) async throws -> [DriverStint]

    /// 이미 정리한 같은 세션·드라이버 자료로 상황을 연결한다. 추가 조회와 취소 처리는 없다.
    /// - Parameters:
    ///   - recordedAt: 실제 발화 시각과 다를 수 있는 라디오 기록 절대 시각.
    ///   - laps: 성공한 랩 자료. nil은 성공 자료 미준비, 빈 배열은 정상 정보 부재다.
    ///   - positions: 성공한 순위 자료. nil과 빈 배열을 구분하며 랩과 독립적으로 연결한다.
    ///   - stints: 성공한 스틴트 자료. 결정된 현재 또는 마지막 완료 랩에 연결한다.
    /// - Returns: 입력 순서와 무관한 항목별 결과. 정보 부재·충돌은 오류 대신 결과로 표현한다.
    func resolveContext(
        recordedAt: Date,
        laps: [DriverLap]?,
        positions: [DriverPosition]?,
        stints: [DriverStint]?
    ) -> RadioContext
}
