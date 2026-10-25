//
//  RaceSessionKind.swift
//  RadioLap
//

import Foundation

/// 외부 응답 형식과 독립적으로 확인된 세션 종류.
/// 판별할 수 없는 종류는 이 타입의 other가 아닌 RaceCandidate.kind의 nil로 표현한다.
nonisolated enum RaceSessionKind: Equatable, Sendable {
    /// 결승으로 확인된 세션.
    case race

    /// 연습·예선·스프린트처럼 결승이 아님을 확인한 세션.
    case other
}
