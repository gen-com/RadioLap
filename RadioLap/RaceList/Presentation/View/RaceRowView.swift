//
//  RaceRowView.swift
//  RadioLap
//

import SwiftUI

struct RaceRowView: View {
    @Environment(\.locale) private var locale
    @ScaledMetric private var dateWidth = 52
    
    let race: Race
    let timeZone: TimeZone
    let onSelect: () -> Void

    var body: some View {
        let date = RaceDateLabels(date: race.startsAt, timeZone: timeZone, locale: locale)
        Button(action: onSelect) {
            HStack(spacing: 14) {
                VStack(spacing: 2) {
                    Text(date.month).font(.caption)
                    Text(date.day).font(.title2.weight(.medium))
                }
                .frame(width: dateWidth)
                .padding(.vertical, 6)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(uiColor: .separator), lineWidth: 0.5))

                VStack(alignment: .leading, spacing: 5) {
                    Text(race.name).font(.body.weight(.medium))
                    Text("\(race.location ?? "장소 정보 없음") · 결승")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(date.time).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(race.name), \(date.fullDate), \(race.location ?? "장소 정보 없음"), 결승")
        .accessibilityHint("레이스 상세 화면으로 이동")
        .accessibilityIdentifier("race.\(race.sessionID)")
    }
}
