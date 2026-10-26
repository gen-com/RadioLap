//
//  RadioPlaybackView.swift
//  RadioLap
//

import SwiftUI

struct RadioPlaybackView: View {
    let state: RadioPlaybackState
    let position: TimeInterval?
    let duration: TimeInterval?
    let onPlay: () -> Void
    let onPause: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Button(action: canPause ? onPause : onPlay) {
                    Label(buttonTitle, systemImage: canPause ? "pause.fill" : "play.fill")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("driverRadio.playback")
                if state == .preparing { ProgressView() }
                Text(status).font(.subheadline).foregroundStyle(.secondary)
            }
            if let position {
                if let duration, duration > 0 {
                    ProgressView(value: min(max(position, 0), duration), total: duration)
                        .accessibilityLabel("재생 진행")
                    Text("\(elapsed(position)) / \(elapsed(duration))")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                } else {
                    Text("재생 경과 \(elapsed(position))")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var canPause: Bool { state == .playing || state == .preparing }

    private var buttonTitle: String {
        switch state {
        case .playing, .preparing: "일시정지"
        case .paused: "이어 듣기"
        case .ended: "다시 듣기"
        case .failed: "다시 시도"
        case .idle: "재생"
        }
    }

    private var status: String {
        switch state {
        case .idle: "재생 대기"
        case .preparing: "오디오를 준비하는 중입니다"
        case .playing: "재생 중"
        case .paused: "일시정지됨"
        case .ended: "재생 완료"
        case .failed: "오디오를 재생하지 못했습니다"
        }
    }

    private func elapsed(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }
}
