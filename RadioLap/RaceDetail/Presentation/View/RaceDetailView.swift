//
//  RaceDetailView.swift
//  RadioLap
//

import SwiftUI

/// 상세 화면의 상태와 스크롤 위치를 소유하고 조회·선택·복귀를 연결한다.
struct RaceDetailView<Model: RaceDetailPresentation>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel: Model
    @State private var timeZone = TimeZone.current
    @State private var hasRequestedInitialLoad = false
    @State private var scrollPosition = ScrollPosition(edge: .top)
    @State private var selection: DriverDestination?

    init(viewModel: Model) {
        _viewModel = State(initialValue: viewModel)
    }

    init(race: Race, dependency: any RaceDetailDependency) where Model == RaceDetailViewModel {
        self.init(viewModel: RaceDetailViewModel(race: race, useCase: dependency.raceDetailUseCase))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Button(action: { dismiss() }) {
                    Label("레이스", systemImage: "chevron.left")
                        .font(.body)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("raceDetail.back")

                RaceDetailHeaderView(race: viewModel.race, timeZone: timeZone)
                RaceDetailContentView(
                    state: viewModel.state,
                    onReload: { viewModel.load() },
                    onSelect: { driver in
                        selection = DriverDestination(sessionID: viewModel.race.sessionID,
                                                      driverNumber: driver.driverNumber, name: driver.name)
                    }
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemBackground))
        .scrollPosition($scrollPosition)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("raceDetail.\(viewModel.race.sessionID)")
        .task {
            guard !hasRequestedInitialLoad else { return }
            hasRequestedInitialLoad = true
            viewModel.load()
        }
        .onDisappear { viewModel.cancel() }
        .navigationDestination(item: $selection) { destination in
            DriverRadioPlaceholder(destination: destination)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange)) { _ in
            timeZone = .current
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            timeZone = .current
        }
    }
}

private struct DriverDestination: Hashable {
    let sessionID: Int
    let driverNumber: Int
    let name: String

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.sessionID == rhs.sessionID && lhs.driverNumber == rhs.driverNumber
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(sessionID)
        hasher.combine(driverNumber)
    }
}

/// 라디오 기능 구현 전에 드라이버 선택과 상세 복귀를 확인하는 임시 이동 화면.
private struct DriverRadioPlaceholder: View {
    @Environment(\.dismiss) private var dismiss
    let destination: DriverDestination

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Button(action: { dismiss() }) {
                Label("레이스 상세", systemImage: "chevron.left")
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("driverRadio.back")
            ContentUnavailableView {
                Label(destination.name, systemImage: "waveform")
            } description: {
                Text("라디오 화면을 준비하고 있습니다.")
            }
        }
        .padding(.horizontal, 24)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("driverRadio.\(destination.sessionID).\(destination.driverNumber)")
    }
}
