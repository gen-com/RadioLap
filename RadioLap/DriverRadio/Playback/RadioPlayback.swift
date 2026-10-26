//
//  RadioPlayback.swift
//  RadioLap
//

import Foundation
import Observation

/// 화면마다 전용으로 소유하는 재생 객체. 상태 원본과 오디오 진행·중단을 담당한다.
@MainActor
protocol RadioPlayback: AnyObject, Observable {
    /// 현재 재생 상태. 준비 중에는 최초 준비와 재생 도중 데이터 대기를 포함한다.
    var state: RadioPlaybackState { get }
    /// 재생 경과 시간(초). 아직 모르면 nil이다.
    var position: TimeInterval? { get }
    /// 전체 길이(초). 아직 모르면 nil이다.
    var duration: TimeInterval? { get }

    /// 기존 작업을 교체하고 주어진 URL을 처음부터 재생한다.
    func play(url: URL)
    /// 일시정지 위치에서 이어 재생한다.
    func resume()
    /// 위치를 보존하고 준비 완료 뒤 자동 재생도 막는다.
    func pause()
    /// 기존 작업을 무효화하고 대기 상태로 초기화한다.
    func stop()
    /// 앱 비활성화로 일시정지하며 자동 재개하지 않는다.
    func deactivate()
}

/// 사용자에게 구분해 제공할 재생 상태.
nonisolated enum RadioPlaybackState: Equatable, Sendable {
    case idle
    case preparing
    case playing
    case paused
    case ended
    case failed
}
