//
//  DriverRadioView.swift
//  RadioLap
//

import SwiftUI

/// 진입 정보와 화면 수명을 유지하고 조회·선택·재생·복귀 이벤트를 연결한다.
struct DriverRadioView<Model: DriverRadioPresentation>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: Model?
    @State private var timeZone = TimeZone.current
    @State private var scrollPosition = ScrollPosition(edge: .top)

    private let race: Race
    private let driver: RaceDriver
    private let initializeModel: () -> Model

    init(viewModel: Model) {
        race = viewModel.race
        driver = viewModel.driver
        _viewModel = State(initialValue: viewModel)
        initializeModel = { viewModel }
    }

    init(race: Race, driver: RaceDriver, component: DriverRadioComponent)
    where Model == DriverRadioViewModel {
        self.race = race
        self.driver = driver
        // SwiftUI가 View 값을 다시 만들 때 전용 재생 객체까지 재생성하지 않는다.
        initializeModel = {
            DriverRadioViewModel(race: race, driver: driver, useCase: component.driverRadioUseCase,
                                 playback: component.newPlayback())
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Button {
                    viewModel?.leave()
                    dismiss()
                } label: {
                    Label(race.name, systemImage: "chevron.left")
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("driverRadio.back")

                DriverRadioHeaderView(race: race, driver: driver)

                if let viewModel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("팀 라디오").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        Text("시간순 · \(timeZone.identifier)")
                            .font(.subheadline).foregroundStyle(.secondary)
                        RadioDataStatusView(title: "랩", state: viewModel.lapsState) { viewModel.retry(.laps) }
                        RadioDataStatusView(title: "순위", state: viewModel.positionsState) { viewModel.retry(.positions) }
                        RadioDataStatusView(title: "타이어", state: viewModel.stintsState) { viewModel.retry(.stints) }
                        radioContent(viewModel)
                    }
                } else {
                    ProgressView("라디오를 불러오는 중입니다")
                }
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
        .accessibilityIdentifier("driverRadio.\(race.sessionID).\(driver.driverNumber)")
        .task {
            if viewModel == nil { viewModel = initializeModel() }
            viewModel?.load()
        }
        .onDisappear { viewModel?.leave() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                timeZone = .current
            } else {
                viewModel?.deactivate()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange)) { _ in
            timeZone = .current
        }
    }

    @ViewBuilder
    private func radioContent(_ model: Model) -> some View {
        switch model.radioState {
        case .idle, .loading:
            ProgressView("라디오를 불러오는 중입니다")
        case .failed, .cancelled:
            RadioDataStatusView(title: "라디오", state: model.radioState) { model.retry(.radio) }
        case .loaded(let records):
            if records.isEmpty {
                Text("공개된 라디오 기록이 없습니다")
                    .foregroundStyle(.secondary).padding(.vertical, 24)
            } else {
                ForEach(records) { record in
                    let context = model.context(for: record.id)
                    RadioCardView(record: record, lap: context?.lap,
                                  expanded: model.selectedRadioID == record.id, timeZone: timeZone,
                                  onSelect: { model.selectRadio(record.id) }) {
                        RadioPlaybackView(state: model.playbackState, position: model.playbackPosition,
                                          duration: model.playbackDuration, onPlay: { model.play() },
                                          onPause: { model.pause() })
                        if let context {
                            RadioContextView(context: context, recordedAt: record.recordedAt, timeZone: timeZone)
                        }
                    }
                }
            }
        }
    }
}

private struct DriverRadioHeaderView: View {
    let race: Race
    let driver: RaceDriver

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(race.name) · \(String(race.season))")
                .font(.subheadline).foregroundStyle(.secondary)
            Text(driver.name).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
            Text(driver.teamName ?? "팀 정보 없음").foregroundStyle(.secondary)
        }
    }
}

/// 성공 자료의 빈 배열은 연결 결과에서 다루고, 조회 상태만 별도로 알린다.
private struct RadioDataStatusView<Value: Equatable & Sendable>: View {
    let title: String
    let state: RadioLoadState<Value>
    let onRetry: () -> Void

    var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView("\(title) 정보를 불러오는 중입니다").font(.subheadline)
        case .failed, .cancelled:
            VStack(alignment: .leading, spacing: 4) {
                Text(message).font(.subheadline)
                Button("\(title) 다시 불러오기", action: onRetry).frame(minHeight: 44)
            }
        case .loaded:
            EmptyView()
        }
    }

    private var message: String {
        if case .cancelled = state { return "\(title) 정보 불러오기가 취소되었습니다" }
        return "\(title) 정보를 불러오지 못했습니다"
    }
}
