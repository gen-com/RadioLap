//
//  RaceDriverRowView.swift
//  RadioLap
//

import SwiftUI

/// 참가자 정보와 결과를 표시하고 드라이버 선택을 전달한다.
struct RaceDriverRowView: View {
    @ScaledMetric private var positionWidth = 32
    @ScaledMetric private var acronymSize = 42

    let driver: RaceDriver
    let onSelect: () -> Void

    private var statusLabels: [String] {
        guard let result = driver.result else { return [] }
        return [result.didNotFinish ? "DNF · 미완주" : nil,
                result.didNotStart ? "DNS · 미출발" : nil,
                result.isDisqualified ? "DSQ · 실격" : nil].compactMap { $0 }
    }

    private var positionLabel: String {
        guard let result = driver.result else { return "결과 미제공" }
        return result.position.map { "\($0)위" } ?? "순위 없음"
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Text(driver.result?.position.map(String.init) ?? "—")
                    .font(.title2.weight(.medium))
                    .monospacedDigit()
                    .frame(minWidth: positionWidth)
                if let acronym = driver.acronym {
                    Text(acronym)
                        .font(.caption)
                        .padding(8)
                        .frame(minWidth: acronymSize, minHeight: acronymSize)
                        .background(Color(.secondarySystemBackground), in: Capsule())
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(driver.name).font(.body.weight(.medium))
                    Text(driver.teamName ?? "팀 정보 없음")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !statusLabels.isEmpty {
                        Text(statusLabels.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
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
        .accessibilityLabel(([positionLabel, driver.name, driver.teamName ?? "팀 정보 없음"] + statusLabels).joined(separator: ", "))
        .accessibilityHint("드라이버 라디오 화면으로 이동")
        .accessibilityIdentifier("raceDetail.driver.\(driver.driverNumber)")
    }
}
