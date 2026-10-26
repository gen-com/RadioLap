//
//  RadioPlayer.swift
//  RadioLap
//

import Foundation
import Observation

/// 현재 준비 작업과 사용자의 재생 의도를 기준으로 오디오 이벤트를 처리한다.
@MainActor
@Observable
final class RadioPlayer: RadioPlayback {
    private(set) var state: RadioPlaybackState = .idle
    private(set) var position: TimeInterval?
    private(set) var duration: TimeInterval?

    private let transport: any RadioAudioTransport
    @ObservationIgnored private var preparationID: UUID?
    @ObservationIgnored private var wantsPlayback = false
    @ObservationIgnored private var isPrepared = false
    @ObservationIgnored private var hasPlayRequest = false

    init(transport: any RadioAudioTransport) {
        self.transport = transport
    }

    func play(url: URL) {
        let id = UUID()
        // 준비 중 동기 이벤트가 도착해도 새 작업에 반영할 수 있도록 먼저 설정한다.
        preparationID = id
        wantsPlayback = true
        isPrepared = false
        hasPlayRequest = false
        position = nil
        duration = nil
        state = .preparing
        transport.prepare(url: url) { [weak self] event in
            guard let self, self.preparationID == id else { return }
            self.receive(event)
        }
    }

    func resume() {
        guard state == .paused, preparationID != nil else { return }
        wantsPlayback = true
        state = .preparing
        requestPlaybackIfPrepared()
    }

    func pause() {
        guard preparationID != nil else { return }
        wantsPlayback = false
        hasPlayRequest = false
        state = .paused
        transport.pause()
    }

    func deactivate() { pause() }

    func stop() {
        preparationID = nil
        wantsPlayback = false
        isPrepared = false
        hasPlayRequest = false
        state = .idle
        position = nil
        duration = nil
        transport.stop()
    }

    private func requestPlaybackIfPrepared() {
        guard wantsPlayback, isPrepared, !hasPlayRequest else { return }
        hasPlayRequest = true
        transport.play()
    }

    private func receive(_ event: RadioAudioEvent) {
        switch event {
        case .ready:
            isPrepared = true
            requestPlaybackIfPrepared()
        case .waiting:
            // 데이터 대기 중에도 최초 준비는 유지해 사용자 재개 명령을 전달한다.
            if wantsPlayback { state = .preparing }
        case .playing:
            guard wantsPlayback else {
                transport.pause()
                return
            }
            isPrepared = true
            state = .playing
        case .progress(let position, let duration):
            self.position = position
            self.duration = duration
        case .ended, .failed:
            preparationID = nil
            wantsPlayback = false
            hasPlayRequest = false
            isPrepared = false
            if case .ended = event { state = .ended } else { state = .failed }
            // 종료·실패 후 이미 전달 중인 이벤트는 무효화한 뒤 자원을 정리한다.
            transport.stop()
        case .interrupted:
            pause()
        }
    }
}
