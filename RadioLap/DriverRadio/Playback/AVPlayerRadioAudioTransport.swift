//
//  AVPlayerRadioAudioTransport.swift
//  RadioLap
//

import AVFoundation

/// 준비한 오디오의 실제 상태를 전달하며 재생 의도는 RadioPlayer에 맡긴다.
@MainActor
final class AVPlayerRadioAudioTransport: RadioAudioTransport {
    private var player: AVPlayer?
    private var onEvent: (@MainActor @Sendable (RadioAudioEvent) -> Void)?
    private var observations: [NSKeyValueObservation] = []
    private var notifications: [NSObjectProtocol] = []
    private var timeObserver: Any?
    private var activatedSession = false

    isolated deinit {
        stop()
    }

    func prepare(url: URL, onEvent: @escaping @MainActor @Sendable (RadioAudioEvent) -> Void) {
        stop()
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        self.onEvent = onEvent

        // 각 관찰은 준비 당시의 콜백을 보관해 이전 이벤트를 새 오디오에 전달하지 않는다.
        observations = [
            item.observe(\.status, options: [.initial, .new]) { item, _ in
                let status = item.status
                Task { @MainActor in
                    switch status {
                    case .readyToPlay: onEvent(.ready)
                    case .failed: onEvent(.failed)
                    case .unknown: break
                    @unknown default: break
                    }
                }
            },
            item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { item, _ in
                guard item.isPlaybackLikelyToKeepUp else { return }
                Task { @MainActor in onEvent(.ready) }
            },
            player.observe(\.status, options: [.new]) { player, _ in
                guard player.status == .failed else { return }
                Task { @MainActor in onEvent(.failed) }
            },
            player.observe(\.timeControlStatus, options: [.new]) { player, _ in
                let status = player.timeControlStatus
                Task { @MainActor in
                    switch status {
                    case .waitingToPlayAtSpecifiedRate: onEvent(.waiting)
                    case .playing: onEvent(.playing)
                    case .paused: break
                    @unknown default: break
                    }
                }
            },
            item.observe(\.duration, options: [.initial, .new]) { [weak player] _, _ in
                Task { @MainActor in
                    guard let player else { return }
                    Self.reportProgress(player: player, onEvent: onEvent)
                }
            }
        ]
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main
        ) { [weak player] _ in
            MainActor.assumeIsolated {
                guard let player else { return }
                Self.reportProgress(player: player, onEvent: onEvent)
            }
        }

        let center = NotificationCenter.default
        notifications = [
            center.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main) {
                [weak player] _ in
                MainActor.assumeIsolated {
                    if let player { Self.reportProgress(player: player, onEvent: onEvent) }
                    onEvent(.ended)
                }
            },
            center.addObserver(forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: item, queue: .main) { _ in
                MainActor.assumeIsolated { onEvent(.failed) }
            },
            center.addObserver(forName: AVAudioSession.didBecomeInactiveNotification,
                               object: AVAudioSession.sharedInstance(), queue: .main) { _ in
                MainActor.assumeIsolated { onEvent(.interrupted) }
            },
            center.addObserver(forName: AVAudioSession.routeChangeNotification,
                               object: AVAudioSession.sharedInstance(), queue: .main) { notification in
                guard let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
                else { return }
                MainActor.assumeIsolated { onEvent(.interrupted) }
            }
        ]
    }

    func play() {
        guard let player else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
            activatedSession = true
            player.play()
        } catch {
            onEvent?(.failed)
        }
    }

    func pause() {
        player?.pause()
    }

    func stop() {
        observations.removeAll()
        for notification in notifications {
            NotificationCenter.default.removeObserver(notification)
        }
        notifications.removeAll()
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        onEvent = nil
        if activatedSession {
            // 오디오 해제 뒤 세션 해제 실패로 종료한 재생 상태를 바꾸지 않는다.
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            activatedSession = false
        }
    }

    private static func reportProgress(
        player: AVPlayer, onEvent: @MainActor @Sendable (RadioAudioEvent) -> Void
    ) {
        let position = player.currentTime().seconds
        let duration = player.currentItem?.duration.seconds
        onEvent(.progress(
            position: position.isFinite ? position : nil,
            duration: duration.flatMap { $0.isFinite ? $0 : nil }
        ))
    }
}
