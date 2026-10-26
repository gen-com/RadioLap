//
//  DriverRadioViewModel.swift
//  RadioLap
//

import Foundation
import Observation

/// 자료별 요청과 교신 선택을 관리하고 상황 계산·오디오 제어를 각 계약에 위임한다.
@MainActor
@Observable
final class DriverRadioViewModel: DriverRadioPresentation {
    let race: Race
    let driver: RaceDriver
    private(set) var radioState: RadioLoadState<[RadioRecord]> = .idle
    private(set) var lapsState: RadioLoadState<[DriverLap]> = .idle
    private(set) var positionsState: RadioLoadState<[DriverPosition]> = .idle
    private(set) var stintsState: RadioLoadState<[DriverStint]> = .idle
    private(set) var selectedRadioID: RadioRecordID?

    var playbackState: RadioPlaybackState { playback.state }
    var playbackPosition: TimeInterval? { playback.position }
    var playbackDuration: TimeInterval? { playback.duration }

    private let useCase: any DriverRadioUseCase
    private let playback: any RadioPlayback
    @ObservationIgnored private var tasks: [RadioDataKind: Task<Void, Never>] = [:]
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var hasLeft = false

    init(race: Race, driver: RaceDriver, useCase: any DriverRadioUseCase, playback: any RadioPlayback) {
        self.race = race
        self.driver = driver
        self.useCase = useCase
        self.playback = playback
    }

    func load() {
        guard !hasLoaded, !hasLeft else { return }
        hasLoaded = true
        for kind in [RadioDataKind.radio, .laps, .positions, .stints] { request(kind) }
    }

    func retry(_ data: RadioDataKind) {
        guard !hasLeft else { return }
        let allowed: Bool
        switch data {
        case .radio: allowed = canRetry(radioState)
        case .laps: allowed = canRetry(lapsState)
        case .positions: allowed = canRetry(positionsState)
        case .stints: allowed = canRetry(stintsState)
        }
        if allowed { request(data) }
    }

    func selectRadio(_ id: RadioRecordID) {
        guard !hasLeft, records.contains(where: { $0.id == id }) else { return }
        playback.stop()
        selectedRadioID = selectedRadioID == id ? nil : id
    }

    func play() {
        guard !hasLeft, let selected = records.first(where: { $0.id == selectedRadioID }) else { return }
        switch playback.state {
        case .idle, .ended, .failed: playback.play(url: selected.recordingURL)
        case .paused: playback.resume()
        case .preparing, .playing: break
        }
    }

    func pause() {
        guard !hasLeft else { return }
        playback.pause()
    }

    func deactivate() {
        guard !hasLeft else { return }
        playback.deactivate()
    }

    func leave() {
        hasLeft = true
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
        if case .loading = radioState { radioState = .cancelled }
        if case .loading = lapsState { lapsState = .cancelled }
        if case .loading = positionsState { positionsState = .cancelled }
        if case .loading = stintsState { stintsState = .cancelled }
        selectedRadioID = nil
        playback.stop()
    }

    func context(for id: RadioRecordID) -> RadioContext? {
        guard let record = records.first(where: { $0.id == id }) else { return nil }
        return useCase.resolveContext(recordedAt: record.recordedAt, laps: loaded(lapsState),
                                      positions: loaded(positionsState), stints: loaded(stintsState))
    }

    private var records: [RadioRecord] { loaded(radioState) ?? [] }

    private func loaded<Value>(_ state: RadioLoadState<Value>) -> Value? {
        if case .loaded(let value) = state { return value }
        return nil
    }

    private func canRetry<Value>(_ state: RadioLoadState<Value>) -> Bool {
        switch state {
        case .failed, .cancelled: true
        case .idle, .loading, .loaded: false
        }
    }

    private func request(_ kind: RadioDataKind) {
        let useCase = useCase
        let sessionID = race.sessionID
        let driverNumber = driver.driverNumber
        switch kind {
        case .radio:
            start(kind, state: \.radioState) { try await useCase.fetchRadioRecords(sessionID: sessionID, driverNumber: driverNumber) }
        case .laps:
            start(kind, state: \.lapsState) { try await useCase.fetchLaps(sessionID: sessionID, driverNumber: driverNumber) }
        case .positions:
            start(kind, state: \.positionsState) { try await useCase.fetchPositions(sessionID: sessionID, driverNumber: driverNumber) }
        case .stints:
            start(kind, state: \.stintsState) { try await useCase.fetchStints(sessionID: sessionID, driverNumber: driverNumber) }
        }
    }

    private func start<Value: Equatable & Sendable>(
        _ kind: RadioDataKind, state: ReferenceWritableKeyPath<DriverRadioViewModel, RadioLoadState<Value>>,
        fetch: @escaping @Sendable () async throws -> Value
    ) {
        tasks[kind]?.cancel()
        self[keyPath: state] = .loading
        tasks[kind] = Task { [weak self] in
            guard !Task.isCancelled else { return }
            let result: RadioLoadState<Value>
            do { result = .loaded(try await fetch()) }
            catch is CancellationError { result = .cancelled }
            catch { result = .failed }
            // 취소된 작업은 현재 상태뿐 아니라 다음 요청의 작업 참조도 변경하지 않는다.
            guard !Task.isCancelled, let self, !self.hasLeft else { return }
            self[keyPath: state] = result
            self.tasks[kind] = nil
        }
    }
}
