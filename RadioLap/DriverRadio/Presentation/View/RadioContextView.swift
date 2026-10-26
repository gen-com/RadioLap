//
//  RadioContextView.swift
//  RadioLap
//

import SwiftUI

/// 연결 결과와 그 근거를 표현하며 원본 자료에서 상황을 다시 계산하지 않는다.
struct RadioContextView: View {
    let context: RadioContext
    let recordedAt: Date
    let timeZone: TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("기록 시각 주변의 상황").font(.headline).accessibilityAddTraits(.isHeader)
            Text("라디오 기록 시각은 실제 발화 시각과 다를 수 있습니다.")
                .font(.caption).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 16) {
                contextItem("랩", value: lapSummary)
                contextItem("순위", value: positionSummary)
                contextItem("타이어", value: tyreSummary)
            }
            DisclosureGroup("상황을 연결한 기준") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(lapBasis)
                    Text(positionBasis)
                    Text(tyreBasis)
                }
                .font(.subheadline).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            }
            .font(.subheadline)
        }
    }

    private func contextItem(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.body)
        }
        .accessibilityElement(children: .combine)
    }

    private var lapSummary: String {
        switch context.lap {
        case .current(let number, _, _): "\(number)랩"
        case .lastCompleted(let number, let end):
            "마지막 확인 · \(number)랩\n종료 후 \(Duration.seconds(recordedAt.timeIntervalSince(end)).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))) 경과"
        case .unavailable: "연결할 정보 없음"
        case .conflicting: "정보를 확정할 수 없음 · 랩 구간 충돌"
        case .notLoaded: "랩 자료 미준비"
        }
    }

    private var positionSummary: String {
        switch context.position {
        case .recorded(let position, let date): "\(position)위 · \(timestamp(date)) 기록"
        case .unavailable: "연결할 정보 없음"
        case .notLoaded: "순위 자료 미준비"
        }
    }

    private var tyreSummary: String {
        switch context.tyre {
        case .current(let compound): compound
        case .lastCompleted(let compound): "마지막 확인 · \(compound)"
        case .unavailable: "연결할 정보 없음"
        case .conflicting: "정보를 확정할 수 없음 · 컴파운드 충돌"
        case .incomplete: "정보를 확정할 수 없음 · 컴파운드 누락"
        case .lapUnavailable: "타이어를 연결하려면 랩 정보가 필요합니다"
        case .stintsNotLoaded: "타이어 자료 미준비"
        }
    }

    private var lapBasis: String {
        switch context.lap {
        case .current(_, let start, let end):
            "랩: 기록 시각이 시작 \(timestamp(start)) 이상, 종료 \(timestamp(end)) 미만인 구간에 연결했습니다."
        case .lastCompleted(_, let end):
            "랩: 현재 구간을 연결할 수 없어 기록 시각 이전에 마지막으로 완료한 랩을 표시합니다. 종료 시각은 \(timestamp(end))입니다."
        case .unavailable: "랩: 기록 시각에 연결할 유효 구간이나 이전 완료 랩이 없습니다."
        case .conflicting: "랩: 적용할 구간이 겹치거나 마지막 완료 시각이 같아 하나를 고를 수 없습니다."
        case .notLoaded: "랩: 조회 자료가 아직 준비되지 않았습니다. 위의 랩 조회 안내를 확인하세요."
        }
    }

    private var positionBasis: String {
        switch context.position {
        case .recorded(_, let date):
            "순위: 라디오 기록 시각 이전 또는 같은 시각의 가장 최근 기록(\(timestamp(date)))입니다. 랩과 독립적으로 연결합니다."
        case .unavailable: "순위: 라디오 기록 시각 이전 또는 같은 시각의 기록이 없습니다."
        case .notLoaded: "순위: 조회 자료가 아직 준비되지 않았습니다. 위의 순위 조회 안내를 확인하세요."
        }
    }

    private var tyreBasis: String {
        switch context.tyre {
        case .current, .lastCompleted:
            let prefix: String
            switch context.lap {
            case .current(let number, _, _): prefix = "\(number)랩"
            case .lastCompleted(let number, _): prefix = "마지막으로 완료한 \(number)랩"
            default: prefix = "연결된 랩"
            }
            return "타이어: \(prefix)을 시작·종료 랩 범위에 포함하는 스틴트 자료로 연결했습니다."
        case .unavailable: return "타이어: 기준 랩에 적용할 유효한 스틴트 범위가 없습니다."
        case .conflicting: return "타이어: 기준 랩에 적용되는 컴파운드가 서로 다릅니다."
        case .incomplete: return "타이어: 기준 랩에 적용되는 자료에 컴파운드가 빠져 있습니다."
        case .lapUnavailable: return "타이어: 먼저 기준 랩을 연결해야 합니다. 랩 자료가 준비되어도 충돌이나 정보 부재로 연결하지 못할 수 있습니다."
        case .stintsNotLoaded: return "타이어: 스틴트 자료가 아직 준비되지 않았습니다. 위의 타이어 조회 안내를 확인하세요."
        }
    }

    private func timestamp(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .numeric, time: .standard, timeZone: timeZone))
    }
}
