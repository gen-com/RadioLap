//
//  RadioAudioTransportSpy.swift
//  RadioLapTests
//

import Foundation
import Testing

/// 명령을 기록하고 요청별 콜백을 보관한다. 최신 작업 판정·재생 정책은 수행하지 않는다.
@MainActor
final class RadioAudioTransportSpy: RadioAudioTransport {
    enum Command: Equatable {
        case prepare(URL)
        case play
        case pause
        case stop
    }

    private(set) var commands: [Command] = []
    private var callbacks: [@MainActor @Sendable (RadioAudioEvent) -> Void] = []
    var eventDuringPrepare: RadioAudioEvent?

    func prepare(url: URL, onEvent: @escaping @MainActor @Sendable (RadioAudioEvent) -> Void) {
        commands.append(.prepare(url))
        callbacks.append(onEvent)
        if let eventDuringPrepare { onEvent(eventDuringPrepare) }
    }

    func play() { commands.append(.play) }
    func pause() { commands.append(.pause) }
    func stop() { commands.append(.stop) }

    /// 교체·중지 후에도 이전 콜백을 호출할 수 있어야 정책 객체의 차단을 검증할 수 있다.
    func send(_ event: RadioAudioEvent, forPreparation index: Int = 0) throws {
        try #require(callbacks.indices.contains(index), "이벤트를 전달할 준비 요청이 없습니다.")
        callbacks[index](event)
    }
}
