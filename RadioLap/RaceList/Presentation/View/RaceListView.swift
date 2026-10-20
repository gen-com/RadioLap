//
//  RaceListView.swift
//  RadioLap
//

import SwiftUI

/// 화면의 수명 동안 ViewModel을 소유하고 공개 상태와 화면 이동을 관리한다.
struct RaceListView<Model: RaceListViewModelProtocol>: View {
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var viewModel: Model
    @State private var timeZone = TimeZone.current
    @State private var selection: RaceDestination?

    init(viewModel: Model) {
        _viewModel = State(initialValue: viewModel)
    }

    init(dependency: any RaceListDependency) where Model == RaceListViewModel {
        self.init(viewModel: RaceListViewModel(repository: dependency.raceListRepository))
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
                                selection = RaceDestination(sessionID: race.sessionID, name: race.name)
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
            .task { viewModel.load() }
            .onDisappear { viewModel.cancel() }
            .navigationDestination(item: $selection) { destination in
                RaceDetailPlaceholder(sessionID: destination.sessionID, name: destination.name)
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
    let sessionID: Int
    let name: String
}

/// 상세 기능 구현 전, 선택한 레이스의 이동 연결만 제공한다.
private struct RaceDetailPlaceholder: View {
    let sessionID: Int
    let name: String

    var body: some View {
        ContentUnavailableView {
            Label(name, systemImage: "flag.checkered")
        } description: {
            Text("레이스 상세 화면을 준비하고 있습니다.")
        }
        .navigationTitle("레이스 상세")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .accessibilityIdentifier("raceDetail.\(sessionID)")
    }
}

@MainActor
@Observable
private final class PreviewRaceListModel: RaceListViewModelProtocol {
    var state: RaceListState
    init(_ state: RaceListState) { self.state = state }
    func load() {}
    func cancel() {}
}
