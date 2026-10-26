//
//  DriverStint.swift
//  RadioLap
//

import Foundation

/// 타이어 사용 랩 범위의 근거. 부재·겹침·역전 범위를 보존한다.
nonisolated struct DriverStint: Equatable, Sendable {
    /// 타이어 사용 시작 랩. 원본 누락·null은 nil이다.
    let startLap: Int?

    /// 타이어 사용 종료 랩. 원본 누락·null은 nil이다.
    let endLap: Int?

    /// 컴파운드 정보. Repository는 원문을 보존하며 UseCase는 공백뿐인 값도 nil로 정리한다.
    let compound: String?
}
