//
//  RadioCardView.swift
//  RadioLap
//

import SwiftUI

struct RadioCardView<Content: View>: View {
    let record: RadioRecord
    let lap: LapContext?
    let expanded: Bool
    let timeZone: TimeZone
    let onSelect: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onSelect) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lapLabel).font(.headline)
                        Text(record.recordedAt.formatted(Date.FormatStyle(date: .numeric, time: .standard, timeZone: timeZone)))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(expanded ? "펼침" : "접힘")
            .accessibilityHint("교신을 선택하거나 접습니다")
            if expanded {
                Divider()
                VStack(alignment: .leading, spacing: 24) { content() }
                    .padding(20)
            }
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.quaternary))
    }

    private var lapLabel: String {
        switch lap {
        case .current(let number, _, _): "\(number)랩"
        case .lastCompleted(let number, _): "마지막 확인 · \(number)랩"
        case .conflicting: "랩 정보를 확정할 수 없음"
        case .notLoaded: "랩 정보 미준비"
        case .unavailable, nil: "연결할 랩 정보 없음"
        }
    }
}
