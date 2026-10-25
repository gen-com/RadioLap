//
//  RaceListView.swift
//  RadioLap
//

import SwiftUI

/// 화면의 수명 동안 ViewModel을 소유하며, 조회 상태를 표시하고 화면 이동을 관리한다.
struct RaceListView<Model: RaceListPresentation, Detail: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var viewModel: Model
    @State private var timeZone = TimeZone.current
    @State private var selection: RaceDestination?
    @State private var hasRequestedInitialLoad = false
    @State private var scrollPosition = ScrollPosition(edge: .top)

    private let detail: (Race) -> Detail

    init(viewModel: Model, @ViewBuilder detail: @escaping (Race) -> Detail) {
        _viewModel = State(initialValue: viewModel)
        self.detail = detail
    }

    init(dependency: any RaceListDependency, @ViewBuilder detail: @escaping (Race) -> Detail)
    where Model == RaceListViewModel {
        self.init(viewModel: RaceListViewModel(useCase: dependency.raceListUseCase), detail: detail)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    RaceListHeaderView()
                    VStack(alignment: .leading, spacing: 12) {
                        RaceListSeasonHeaderView()
                        RaceListContentView(
                            state: viewModel.state,
                            timeZone: timeZone,
                            onSelect: { race in
                                selection = RaceDestination(race: race)
                            },
                            onRetry: { viewModel.load() }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemBackground))
            .toolbar(.hidden, for: .navigationBar)
            .scrollPosition($scrollPosition)
            .task {
                guard !hasRequestedInitialLoad else { return }
                hasRequestedInitialLoad = true
                viewModel.load()
            }
            .onDisappear { viewModel.cancel() }
            .navigationDestination(item: $selection) { destination in
                detail(destination.race)
            }
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

private struct RaceListHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RADIO LAP")
                .font(.caption.weight(.medium))
                .tracking(2)
                .foregroundStyle(.secondary)
            Text("레이스")
                .font(.largeTitle.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text("팀 라디오로 돌아보는 레이스")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct RaceListSeasonHeaderView: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("2026").font(.headline)
            Text("최신순")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
        }
    }
}

private struct RaceDestination: Hashable {
    let race: Race

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.race.sessionID == rhs.race.sessionID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(race.sessionID)
    }
}
