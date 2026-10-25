//
//  RaceDetailHeaderView.swift
//  RadioLap
//

import SwiftUI

/// 드라이버 조회 상태와 관계없이 선택한 레이스의 기본 정보를 표시한다.
struct RaceDetailHeaderView: View {
    @Environment(\.locale) private var locale

    let race: Race
    let timeZone: TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(String(race.season)) · 결승")
                .font(.subheadline)
            Text(race.name)
                .font(.largeTitle.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 4) {
                Text(race.startsAt.formatted(Date.FormatStyle(locale: locale, timeZone: timeZone).month().day()))
                    .font(.title3)
                Text(race.location ?? "장소 정보 없음")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("raceDetail.header")
    }
}
