//
//  RaceListContentView.swift
//  RadioLap
//

import SwiftUI

struct RaceListContentView: View {
    let state: RaceListState
    let timeZone: TimeZone
    let onSelect: (Race) -> Void
    let onRetry: () -> Void

    var body: some View {
        switch state {
        case .idle:
            Color.clear.frame(height: 1).accessibilityHidden(true)
        case .loading:
            VStack(spacing: 16) {
                ProgressView()
                Text("레이스를 불러오는 중입니다")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 64)
        case .content(let races):
            LazyVStack(spacing: 0) {
                ForEach(races) { race in
                    RaceRowView(race: race, timeZone: timeZone) { onSelect(race) }
                    Divider()
                }
            }
        case .empty:
            RaceListMessageView(text: "2026 시즌에 조회할 수 있는 종료된 결승이 없습니다", symbol: "flag.checkered")
        case .failed(let text):
            VStack(spacing: 20) {
                RaceListMessageView(text: text, symbol: "exclamationmark.circle")
                Button("다시 시도", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                    .accessibilityIdentifier("raceList.retry")
            }
            .padding(.bottom, 32)
        }
    }
}

private struct RaceListMessageView: View {
    let text: String
    let symbol: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol).font(.title).accessibilityHidden(true)
            Text(text).font(.subheadline).multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 48)
        .padding(.bottom, 16)
    }
}
