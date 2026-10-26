//
//  DriverRadioRepository.swift
//  RadioLap
//

import Foundation

/// 요청 세션·드라이버의 자료를 독립적으로 읽고 Domain 값으로 변환한다.
/// 중복 정리·시점 연결·오디오 접속은 수행하지 않으며 반환 순서는 보장하지 않는다.
nonisolated protocol DriverRadioRepository: Sendable {
    /// 공개 라디오 기록을 조회하며 중복과 정보 부재를 정리하지 않는다.
    /// - Parameters:
    ///   - sessionID: 선택한 레이스의 세션 식별자.
    ///   - driverNumber: 해당 세션에서 선택한 드라이버 번호.
    /// - Returns: 요청 대상의 자료. 정상 기록 부재는 빈 배열이며 순서는 보장하지 않는다.
    /// - Throws: 미지원 요청·읽기·해석·요청 대상 불일치 오류.
    ///   관찰한 취소는 CancellationError로 전달하며 일반 오류 직전에도 호출 취소를 확인한다.
    func fetchRadioRecords(sessionID: Int, driverNumber: Int) async throws -> [RadioRecord]

    /// 랩 번호와 시작 시각·소요 시간을 조회하며 중복과 정보 부재를 정리하지 않는다.
    /// - Parameters:
    ///   - sessionID: 선택한 레이스의 세션 식별자.
    ///   - driverNumber: 해당 세션에서 선택한 드라이버 번호.
    /// - Returns: 요청 대상의 자료. 정상 기록 부재는 빈 배열이며 순서는 보장하지 않는다.
    /// - Throws: 미지원 요청·읽기·해석·요청 대상 불일치 오류.
    ///   관찰한 취소는 CancellationError로 전달하며 일반 오류 직전에도 호출 취소를 확인한다.
    func fetchLaps(sessionID: Int, driverNumber: Int) async throws -> [DriverLap]

    /// 세션 중 순위 기록을 조회하며 중복과 정보 부재를 정리하지 않는다.
    /// - Parameters:
    ///   - sessionID: 선택한 레이스의 세션 식별자.
    ///   - driverNumber: 해당 세션에서 선택한 드라이버 번호.
    /// - Returns: 요청 대상의 자료. 정상 기록 부재는 빈 배열이며 순서는 보장하지 않는다.
    /// - Throws: 미지원 요청·읽기·해석·요청 대상 불일치 오류.
    ///   관찰한 취소는 CancellationError로 전달하며 일반 오류 직전에도 호출 취소를 확인한다.
    func fetchPositions(sessionID: Int, driverNumber: Int) async throws -> [DriverPosition]

    /// 타이어 사용 랩 범위와 컴파운드를 조회하며 중복과 정보 부재를 정리하지 않는다.
    /// - Parameters:
    ///   - sessionID: 선택한 레이스의 세션 식별자.
    ///   - driverNumber: 해당 세션에서 선택한 드라이버 번호.
    /// - Returns: 요청 대상의 자료. 정상 기록 부재는 빈 배열이며 순서는 보장하지 않는다.
    /// - Throws: 미지원 요청·읽기·해석·요청 대상 불일치 오류.
    ///   관찰한 취소는 CancellationError로 전달하며 일반 오류 직전에도 호출 취소를 확인한다.
    func fetchStints(sessionID: Int, driverNumber: Int) async throws -> [DriverStint]
}
