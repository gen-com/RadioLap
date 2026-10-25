//
//  RaceDetailContentView.swift
//  RadioLap
//

import SwiftUI

/// 드라이버 영역의 상태를 표시하고 재조회·선택 이벤트를 상위 화면에 전달한다.
struct RaceDetailContentView: View {
    let state: RaceDetailState
    let onReload: () -> Void
    let onSelect: (RaceDriver) -> Void

    var body: some View {
        switch state {
        case .idle:
            Color.clear.frame(height: 1).accessibilityHidden(true)
        case .loading:
            VStack(spacing: 16) {
                ProgressView()
                Text("드라이버 정보를 불러오는 중입니다")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
        case .content(let groups):
            VStack(alignment: .leading, spacing: 12) {
                Text("드라이버 순위")
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("OpenF1 결승 결과 · \(groups.reduce(0) { $0 + $1.drivers.count })명")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groups.indices, id: \.self) { index in
                        RaceDriverGroupView(group: groups[index], onSelect: onSelect)
                    }
                }
            }
        case .empty:
            RaceDetailMessageView(text: "참가 드라이버 정보가 없습니다", symbol: "person.2")
        case .failed:
            VStack(spacing: 20) {
                RaceDetailMessageView(text: "레이스 정보를 불러오지 못했습니다.", symbol: "exclamationmark.circle")
                Button("다시 시도", action: onReload)
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                    .accessibilityIdentifier("raceDetail.retry")
            }
            .frame(maxWidth: .infinity)
        case .cancelled:
            Button("다시 불러오기", action: onReload)
                .buttonStyle(.borderedProminent)
                .tint(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
                .accessibilityIdentifier("raceDetail.reload")
        }
    }
}

private struct RaceDriverGroupView: View {
    let group: RaceDriverGroup
    let onSelect: (RaceDriver) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if group.kind != .ranked {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(group.kind == .unranked ? "순위 없음" : "결과 미제공") · \(group.drivers.count)명")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text(group.kind == .unranked
                         ? "제공된 순위가 없어 별도로 표시합니다."
                         : "아직 결과가 제공되지 않았습니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 28)
                .padding(.bottom, 8)
            }
            ForEach(group.drivers) { driver in
                RaceDriverRowView(driver: driver) { onSelect(driver) }
                Divider()
            }
        }
    }
}

private struct RaceDetailMessageView: View {
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
        .padding(.top, 40)
        .padding(.bottom, 16)
    }
}
