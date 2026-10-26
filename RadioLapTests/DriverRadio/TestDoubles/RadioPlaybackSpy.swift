//
//  RadioPlaybackSpy.swift
//  RadioLapTests
//

import Foundation
import Observation

/// 명령을 기록하고 테스트가 상태를 직접 공급한다. 재생 정책을 수행하지 않는다.
@MainActor
@Observable
final class RadioPlaybackSpy: RadioPlayback {
    enum Command: Equatable {
        case play(URL)
        case resume
        case pause
        case stop
        case deactivate
    }

    var state: RadioPlaybackState = .idle
    var position: TimeInterval?
    var duration: TimeInterval?
    private(set) var commands: [Command] = []

    func play(url: URL) { commands.append(.play(url)) }
    func resume() { commands.append(.resume) }
    func pause() { commands.append(.pause) }
    func stop() { commands.append(.stop) }
    func deactivate() { commands.append(.deactivate) }
}
