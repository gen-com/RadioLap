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

    private let driverRadioComponent: DriverRadioComponent

    init(viewModel: Model, driverRadioComponent: DriverRadioComponent) {
        _viewModel = State(initialValue: viewModel)
        self.driverRadioComponent = driverRadioComponent
    }

    init(race: Race, component: RaceDetailComponent)
    where Model == RaceDetailViewModel {
        self.init(viewModel: RaceDetailViewModel(race: race, useCase: component.raceDetailUseCase),
                  driverRadioComponent: component.driverRadioComponent)
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
                        selection = DriverDestination(sessionID: viewModel.race.sessionID, driver: driver)
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
            DriverRadioView(race: viewModel.race, driver: destination.driver, component: driverRadioComponent)
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
    let driver: RaceDriver

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.sessionID == rhs.sessionID && lhs.driver.driverNumber == rhs.driver.driverNumber
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(sessionID)
        hasher.combine(driver.driverNumber)
    }
}
