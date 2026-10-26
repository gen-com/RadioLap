//
//  DriverRadioViewModelTests.swift
//  RadioLapTests
//

import Foundation
import Observation
import Testing

@MainActor
final class DriverRadioViewModelTests {

    // MARK: - 테스트: 초기 상태와 독립 조회

    @Test("초기화는 Race·RaceDriver를 보존하고 조회·선택·재생 없이 시작한다")
    func startsIdle() async throws {
        try await withPresentation { presentation, useCase, playback in
            // Act / Assert: 짧은 관찰 구간을 두어 초기화가 예약한 조회도 확인한다.
            try await Task.sleep(for: .milliseconds(200))
            #expect(presentation.race == selectedRace)
            #expect(presentation.driver == selectedDriver)
            #expect(presentation.radioState == .idle)
            #expect(presentation.lapsState == .idle)
            #expect(presentation.positionsState == .idle)
            #expect(presentation.stintsState == .idle)
            #expect(presentation.selectedRadioID == nil)
            #expect(presentation.playbackState == .idle)
            #expect(presentation.playbackPosition == nil)
            #expect(presentation.playbackDuration == nil)
            #expect(await useCase.requests.isEmpty)
            #expect(playback.commands.isEmpty)
        }
    }

    @Test("load는 네 자료를 loading으로 전환하고 응답 대기 없이 각각 같은 식별자로 요청한다")
    func startsIndependentRequests() async throws {
        try await withPresentation { presentation, useCase, playback in
            // Arrange
            await confirmation("조회 상태 변경 알림") { changed in
                withObservationTracking {
                    _ = presentation.radioState
                    _ = presentation.lapsState
                    _ = presentation.positionsState
                    _ = presentation.stintsState
                } onChange: { changed() }

                // Act
                presentation.load()

                // Assert
                #expect(presentation.radioState == .loading)
                #expect(presentation.lapsState == .loading)
                #expect(presentation.positionsState == .loading)
                #expect(presentation.stintsState == .loading)
            }
            // 어느 요청도 완료하지 않은 채 모든 자료의 요청이 도착해야 한다.
            for kind in dataKinds {
                let request = try await useCase.request(kind)
                #expect(request.sessionID == selectedRace.sessionID)
                #expect(request.driverNumber == selectedDriver.driverNumber)
            }
            #expect(presentation.selectedRadioID == nil)
            #expect(playback.commands.isEmpty)
        }
    }

    @Test("자료별 성공·빈 결과·실패·취소를 관찰 가능하게 반영하고 다른 진행 중 조회는 유지한다",
          arguments: [RadioDataKind.radio, .laps, .positions, .stints], Completion.allCases)
    func handlesIndependentCompletion(_ kind: RadioDataKind, _ result: Completion) async throws {
        try await withPresentation { presentation, useCase, playback in
            // Arrange
            presentation.load()
            for data in dataKinds { _ = try await useCase.request(data) }
            let request = try await useCase.request(kind)
            try await confirmation("해당 자료 결과 변경 알림") { changed in
                withObservationTracking {
                    _ = matches(result, for: kind, in: presentation)
                } onChange: { changed() }

                // Act
                try await complete(request, with: result, using: useCase)

                // Assert
                try await waitUntil { matches(result, for: kind, in: presentation) }
            }
            for other in dataKinds where other != kind {
                #expect(isLoading(other, in: presentation))
            }
            #expect(presentation.race == selectedRace)
            #expect(presentation.driver == selectedDriver)
            #expect(presentation.selectedRadioID == nil)
            #expect(playback.commands.isEmpty)
            // 관찰 범위 안에서 실패·취소 후 자동 재요청이 없는지 확인한다.
            try await Task.sleep(for: .milliseconds(200))
            #expect(await useCase.requests.count == 4)
            #expect(matches(result, for: kind, in: presentation))
            for other in dataKinds where other != kind {
                let pending = try await useCase.request(other)
                #expect(!(await useCase.cancelled.contains(pending.id)))
            }
        }
    }

    @Test("load 반복은 진행 중과 모든 완료 상태에서 재조회하지 않는다", arguments: Completion.allCases)
    func ignoresRepeatedLoad(_ result: Completion) async throws {
        try await withPresentation { presentation, useCase, _ in
            // Arrange
            presentation.load()
            for kind in dataKinds { _ = try await useCase.request(kind) }

            // Act
            presentation.load()
            for kind in dataKinds {
                let request = try await useCase.request(kind)
                try await complete(request, with: result, using: useCase)
            }
            try await waitUntil { dataKinds.allSatisfy { matches(result, for: $0, in: presentation) } }
            presentation.load()
            try await Task.sleep(for: .milliseconds(200))

            // Assert
            #expect(await useCase.requests.count == 4)
            for kind in dataKinds { #expect(matches(result, for: kind, in: presentation)) }
        }
    }

    // MARK: - 테스트: 재시도

    @Test("retry는 조회 전·진행 중·성공 상태를 다시 요청하지 않는다",
          arguments: [RadioDataKind.radio, .laps, .positions, .stints], [Completion.content, .empty])
    func retriesOnlyFailedOrCancelled(_ kind: RadioDataKind, _ success: Completion) async throws {
        try await withPresentation { presentation, useCase, _ in
            // Arrange / Act
            presentation.retry(kind)
            try await Task.sleep(for: .milliseconds(200))
            #expect(await useCase.requests.isEmpty)
            presentation.load()
            for data in dataKinds { _ = try await useCase.request(data) }
            presentation.retry(kind)
            let request = try await useCase.request(kind)
            try await complete(request, with: success, using: useCase)
            try await waitUntil { matches(success, for: kind, in: presentation) }
            presentation.retry(kind)
            try await Task.sleep(for: .milliseconds(200))

            // Assert
            #expect(await useCase.requests.count == 4)
            #expect(matches(success, for: kind, in: presentation))
        }
    }

    @Test("실패·취소된 자료만 재시도하고 다른 성공 자료를 보존한다",
          arguments: [RadioDataKind.radio, .laps, .positions, .stints], [Completion.failed, .cancelled])
    func retriesOneDataKind(_ kind: RadioDataKind, _ result: Completion) async throws {
        try await withPresentation { presentation, useCase, playback in
            // Arrange
            presentation.load()
            for data in dataKinds {
                let request = try await useCase.request(data)
                try await complete(request, with: data == kind ? result : .content, using: useCase)
            }
            try await waitUntil {
                dataKinds.allSatisfy { matches($0 == kind ? result : .content, for: $0, in: presentation) }
            }

            // Act
            presentation.retry(kind)
            #expect(isLoading(kind, in: presentation))
            let next = try await useCase.request(kind, at: 1)
            #expect(next.sessionID == selectedRace.sessionID)
            #expect(next.driverNumber == selectedDriver.driverNumber)

            // Assert: 응답을 보류한 동안에도 다른 성공 자료는 그대로 보여야 한다.
            for other in dataKinds where other != kind {
                #expect(matches(.content, for: other, in: presentation))
            }
            #expect(await useCase.requests.count == 5)

            // Act
            try await complete(next, with: .content, using: useCase)
            try await waitUntil { matches(.content, for: kind, in: presentation) }

            // Assert
            for data in dataKinds { #expect(matches(.content, for: data, in: presentation)) }
            #expect(await useCase.requests.count == 5)
            #expect(playback.commands.isEmpty)
        }
    }

    @Test("상황 자료의 재시도와 도착은 선택한 교신·재생·위치를 변경하지 않는다",
          arguments: [RadioDataKind.laps, .positions, .stints])
    func preservesPlaybackWhileRetryingContext(_ kind: RadioDataKind) async throws {
        try await withPresentation { presentation, useCase, playback in
            // Arrange
            let records = try await loadRadio(in: presentation, using: useCase)
            let request = try await useCase.request(kind)
            try await complete(request, with: .failed, using: useCase)
            try await waitUntil { matches(.failed, for: kind, in: presentation) }
            presentation.selectRadio(records[0].id)
            presentation.play()
            playback.state = .playing
            playback.position = 12
            let commands = playback.commands

            // Act
            presentation.retry(kind)
            let retry = try await useCase.request(kind, at: 1)

            // Assert: 재시도 완료 뒤 복원하는 구현과 대기 중에도 유지하는 구현을 구분한다.
            #expect(isLoading(kind, in: presentation))
            #expect(presentation.selectedRadioID == records[0].id)
            #expect(presentation.radioState == .loaded(records))
            #expect(presentation.playbackState == .playing)
            #expect(presentation.playbackPosition == 12)
            #expect(playback.commands == commands)

            // Act
            try await complete(retry, with: .content, using: useCase)
            try await waitUntil { matches(.content, for: kind, in: presentation) }

            // Assert
            #expect(presentation.selectedRadioID == records[0].id)
            #expect(presentation.radioState == .loaded(records))
            #expect(presentation.playbackState == .playing)
            #expect(presentation.playbackPosition == 12)
            #expect(playback.commands == commands)
        }
    }

    // MARK: - 테스트: 교신 선택

    @Test("상황 자료가 없어도 교신을 선택하고 교체·접기 시 재생을 중지한다")
    func selectsWithoutContextAndStopsOnChange() async throws {
        try await withPresentation { presentation, useCase, playback in
            // Arrange
            let records = try await loadRadio(in: presentation, using: useCase)
            #expect(presentation.selectedRadioID == nil)
            #expect(playback.commands.isEmpty)

            // Act: 다른 자료는 응답하지 않은 상태에서 선택한다.
            await confirmation("선택 변경 알림") { changed in
                withObservationTracking { _ = presentation.selectedRadioID } onChange: { changed() }
                presentation.selectRadio(records[0].id)
            }

            // Assert: 최초 선택 시 대기 상태에 중지 명령을 보내는지는 강제하지 않는다.
            #expect(presentation.selectedRadioID == records[0].id)
            #expect(playback.commands.allSatisfy { $0 == .stop })
            presentation.play()
            playback.state = .preparing
            let commands = playback.commands

            // Act / Assert
            presentation.selectRadio(records[1].id)
            #expect(presentation.selectedRadioID == records[1].id)
            #expect(playback.commands == commands + [.stop])
            presentation.selectRadio(records[1].id)
            #expect(presentation.selectedRadioID == nil)
            #expect(playback.commands == commands + [.stop, .stop])
        }
    }

    @Test("목록에 없는 식별자 선택은 기존 선택과 재생에 영향을 주지 않는다")
    func ignoresUnknownSelection() async throws {
        try await withPresentation { presentation, useCase, playback in
            // Arrange
            let records = try await loadRadio(in: presentation, using: useCase)
            presentation.selectRadio(records[0].id)
            playback.state = .playing
            playback.position = 8
            let commands = playback.commands
            let unknown = RadioRecordID(recordedAt: records[0].recordedAt, recordingURLString: "https://example.com/missing")

            // Act
            presentation.selectRadio(unknown)

            // Assert
            #expect(presentation.selectedRadioID == records[0].id)
            #expect(presentation.playbackState == .playing)
            #expect(presentation.playbackPosition == 8)
            #expect(playback.commands == commands)
        }
    }

    // MARK: - 테스트: 재생 제어와 관찰

    @Test("자료 재조회 없이 선택한 교신의 상태에 맞춰 시작·이어 듣기·중복 요청 무시를 구분한다",
          arguments: [RadioPlaybackState.idle, .preparing, .playing, .paused, .ended, .failed])
    func routesPlayCommand(_ state: RadioPlaybackState) async throws {
        try await withPresentation { presentation, useCase, playback in
            // Arrange
            let records = try await loadRadio(in: presentation, using: useCase)
            for kind in dataKinds where kind != .radio {
                let request = try await useCase.request(kind)
                try await complete(request, with: .content, using: useCase)
            }
            try await waitUntil { dataKinds.allSatisfy { matches(.content, for: $0, in: presentation) } }
            presentation.selectRadio(records[1].id)
            playback.state = state
            let previous = playback.commands
            let expected: [RadioPlaybackSpy.Command]
            switch state {
            case .idle, .ended, .failed: expected = [.play(records[1].recordingURL)]
            case .paused: expected = [.resume]
            case .preparing, .playing: expected = []
            }

            try await confirmation("재생 요청으로 조회 상태를 변경하지 않는다", expectedCount: 0) { changed in
                withObservationTracking {
                    _ = presentation.radioState
                    _ = presentation.lapsState
                    _ = presentation.positionsState
                    _ = presentation.stintsState
                } onChange: { changed() }

                // Act
                presentation.play()
                // 예약된 재조회를 확인하는 제한된 관찰 구간이다.
                try await Task.sleep(for: .milliseconds(200))

                // Assert
                #expect(playback.commands == previous + expected)
                #expect(presentation.selectedRadioID == records[1].id)
                for kind in dataKinds { #expect(matches(.content, for: kind, in: presentation)) }
                #expect(await useCase.requests.count == 4)
            }
        }
    }

    @Test("교신을 선택하지 않으면 재생을 요청하지 않는다")
    func ignoresPlayWithoutSelection() async throws {
        try await withPresentation { presentation, useCase, playback in
            // Arrange
            _ = try await loadRadio(in: presentation, using: useCase)

            // Act
            presentation.play()

            // Assert
            #expect(playback.commands.isEmpty)
        }
    }

    @Test("일시정지와 비활성화는 준비·재생 중에도 재생 객체에 전달하고 선택과 자료를 유지한다",
          arguments: [RadioPlaybackState.preparing, .playing])
    func forwardsPauseAndDeactivation(_ state: RadioPlaybackState) async throws {
        try await withPresentation { presentation, useCase, playback in
            // Arrange
            let records = try await loadRadio(in: presentation, using: useCase)
            presentation.selectRadio(records[0].id)
            playback.state = state
            playback.position = 12
            let previous = playback.commands

            // Act
            presentation.pause()
            playback.state = state
            presentation.deactivate()
            playback.state = .paused

            // Assert: 위치 보존 정책 자체는 실제 재생 객체 테스트에서 검증한다.
            #expect(playback.commands == previous + [.pause, .deactivate])
            #expect(presentation.selectedRadioID == records[0].id)
            #expect(presentation.radioState == .loaded(records))
            #expect(presentation.playbackPosition == 12)
            #expect(presentation.playbackState == .paused)
        }
    }

    @Test("재생 객체의 상태·위치·길이 변경을 관찰 가능하게 전달하고 선택·조회·명령을 변경하지 않는다")
    func observesPlaybackValues() async throws {
        try await withPresentation { presentation, useCase, playback in
            // Arrange
            let records = try await loadRadio(in: presentation, using: useCase)
            presentation.selectRadio(records[0].id)
            let commands = playback.commands
            for state in [RadioPlaybackState.preparing, .playing, .paused, .ended, .failed] {
                try await confirmation("재생 상태 변경 알림") { changed in
                    withObservationTracking { _ = presentation.playbackState } onChange: { changed() }
                    // Act
                    playback.state = state
                    // Assert
                    try await waitUntil { presentation.playbackState == state }
                }
            }
            for value in [12.0, nil] as [Double?] {
                try await confirmation("재생 위치 변경 알림") { changed in
                    withObservationTracking { _ = presentation.playbackPosition } onChange: { changed() }
                    playback.position = value
                    try await waitUntil { presentation.playbackPosition == value }
                }
                try await confirmation("전체 길이 변경 알림") { changed in
                    withObservationTracking { _ = presentation.playbackDuration } onChange: { changed() }
                    playback.duration = value
                    try await waitUntil { presentation.playbackDuration == value }
                }
            }
            #expect(presentation.selectedRadioID == records[0].id)
            #expect(presentation.radioState == .loaded(records))
            #expect(playback.commands == commands)
            #expect(await useCase.requests.count == 4)
        }
    }

    // MARK: - 테스트: 동기 상황 연결 위임

    @Test("현재 교신의 기록 시각과 성공 자료만 전달하고 접힌 교신의 계산 결과도 그대로 제공한다")
    func delegatesContextWithAvailableData() async throws {
        // Arrange: 계산 규칙을 재현하지 않고 지정한 결과 전달만 확인한다.
        let records = try radioRecords()
        let expected = RadioContext(lap: .conflicting, position: .unavailable, tyre: .lapUnavailable)
        let inputPositions = positions
        let useCase = DriverRadioUseCaseSpy { recordedAt, laps, positions, stints in
            #expect(recordedAt == records[1].recordedAt)
            #expect(laps == nil)
            #expect(positions == inputPositions)
            #expect(stints == [])
            return expected
        }
        try await withPresentation(useCase: useCase) { presentation, useCase, playback in
            _ = try await loadRadio(in: presentation, using: useCase)
            let lapRequest = try await useCase.request(.laps)
            let positionRequest = try await useCase.request(.positions)
            let stintRequest = try await useCase.request(.stints)
            try await complete(lapRequest, with: .failed, using: useCase)
            try await complete(positionRequest, with: .content, using: useCase)
            try await complete(stintRequest, with: .empty, using: useCase)
            try await waitUntil {
                presentation.lapsState == .failed && presentation.positionsState == .loaded(inputPositions)
                    && presentation.stintsState == .loaded([])
            }

            // Act
            let actual = presentation.context(for: records[1].id)

            // Assert
            #expect(actual == expected)
            #expect(presentation.selectedRadioID == nil)
            #expect(presentation.radioState == .loaded(records))
            #expect(playback.commands.isEmpty)
            #expect(await useCase.requests.count == 4)
        }
    }

    @Test("상황 자료 재시도 전·중에는 nil을 전달하고 성공 후 새 자료로 다시 계산한다")
    func recalculatesContextAfterRetry() async throws {
        // Arrange
        let records = try radioRecords()
        let inputLaps = laps
        let useCase = DriverRadioUseCaseSpy { recordedAt, laps, positions, stints in
            #expect(recordedAt == records[0].recordedAt)
            #expect(laps == inputLaps)
            #expect(positions == nil)
            #expect(stints == nil || stints == [])
            return RadioContext(lap: .current(number: 14, startsAt: Date(timeIntervalSince1970: 500),
                                             endsAt: Date(timeIntervalSince1970: 590)),
                                position: .notLoaded, tyre: stints == nil ? .stintsNotLoaded : .unavailable)
        }
        try await withPresentation(useCase: useCase) { presentation, useCase, playback in
            _ = try await loadRadio(in: presentation, using: useCase)
            let lapRequest = try await useCase.request(.laps)
            let stintRequest = try await useCase.request(.stints)
            try await complete(lapRequest, with: .content, using: useCase)
            try await complete(stintRequest, with: .cancelled, using: useCase)
            try await waitUntil { presentation.lapsState == .loaded(inputLaps) && presentation.stintsState == .cancelled }
            let before = presentation.context(for: records[0].id)

            // Act
            presentation.retry(.stints)
            let retry = try await useCase.request(.stints, at: 1)
            let during = presentation.context(for: records[0].id)
            try await complete(retry, with: .empty, using: useCase)
            try await waitUntil { presentation.stintsState == .loaded([]) }
            let after = presentation.context(for: records[0].id)

            // Assert
            let expectedLap = LapContext.current(number: 14, startsAt: Date(timeIntervalSince1970: 500),
                                                 endsAt: Date(timeIntervalSince1970: 590))
            #expect(before == RadioContext(lap: expectedLap, position: .notLoaded, tyre: .stintsNotLoaded))
            #expect(during == before)
            #expect(after == RadioContext(lap: expectedLap, position: .notLoaded, tyre: .unavailable))
            #expect(playback.commands.isEmpty)
            #expect(await useCase.requests.count == 5)
        }
    }

    @Test("목록에 없는 교신의 상황은 계산하지 않고 nil을 반환한다")
    func ignoresUnknownContext() async throws {
        try await withPresentation { presentation, useCase, _ in
            // Arrange: 기본 대역은 상황 계산을 요청하면 실패를 기록한다.
            _ = try await loadRadio(in: presentation, using: useCase)
            let unknown = RadioRecordID(recordedAt: Date(timeIntervalSince1970: 0), recordingURLString: "missing")

            // Act / Assert
            #expect(presentation.context(for: unknown) == nil)
        }
    }

    // MARK: - 테스트: 이탈과 늦은 응답

    @Test("같은 드라이버의 새 화면은 이전 선택·재생을 복원하지 않고 새로 조회한다")
    func startsFreshOnReentry() async throws {
        try await withPresentation { previous, previousUseCase, previousPlayback in
            // Arrange
            let records = try await loadRadio(in: previous, using: previousUseCase)
            previous.selectRadio(records[0].id)
            previousPlayback.state = .playing
            previousPlayback.position = 12
            let commands = previousPlayback.commands
            previous.leave()
            #expect(previousPlayback.commands == commands + [.stop])

            // Act
            try await withPresentation { current, currentUseCase, currentPlayback in
                // Assert: 새 인스턴스의 초기 상태와 요청을 확인한다. Component 조립은 별도 검토 대상이다.
                #expect(current.selectedRadioID == nil)
                #expect(current.playbackState == .idle)
                #expect(current.playbackPosition == nil)
                #expect(currentPlayback.commands.isEmpty)
                current.load()
                for kind in dataKinds {
                    let request = try await currentUseCase.request(kind)
                    #expect(request.sessionID == selectedRace.sessionID)
                    #expect(request.driverNumber == selectedDriver.driverNumber)
                }
                let oldLaps = try await previousUseCase.request(.laps)
                try await previousUseCase.completeLaps(oldLaps, with: .success(laps))
                previousPlayback.state = .ended
                try await Task.sleep(for: .milliseconds(200))
                for kind in dataKinds { #expect(isLoading(kind, in: current)) }
                #expect(current.selectedRadioID == nil)
                #expect(current.playbackState == .idle)
                #expect(currentPlayback.commands.isEmpty)
            }
        }
    }

    @Test("이탈은 모든 진행 요청을 취소하고 종료를 기다리지 않으며 늦은 성공·실패·취소를 반영하지 않는다",
          arguments: [Completion.content, .failed, .cancelled])
    func ignoresResponsesAfterLeaving(_ result: Completion) async throws {
        try await withPresentation { presentation, useCase, playback in
            // Arrange
            presentation.load()
            var requests: [DriverRadioUseCaseSpy.Request] = []
            for kind in dataKinds { requests.append(try await useCase.request(kind)) }
            let commands = playback.commands

            // Act
            presentation.leave()

            // Assert: 응답을 완료하기 전에 취소 전달과 중지 명령을 확인한다.
            #expect(playback.commands == commands + [.stop])
            for request in requests { try await useCase.waitForCancellation(of: request) }
            let radioState = presentation.radioState
            let lapsState = presentation.lapsState
            let positionsState = presentation.positionsState
            let stintsState = presentation.stintsState
            try await confirmation("이탈 뒤 늦은 응답은 공개 상태를 변경하지 않는다", expectedCount: 0) { changed in
                withObservationTracking {
                    _ = presentation.radioState
                    _ = presentation.lapsState
                    _ = presentation.positionsState
                    _ = presentation.stintsState
                } onChange: { changed() }
                for request in requests { try await complete(request, with: result, using: useCase) }
                // 목록·상세와 같은 제한된 관찰 구간이며 내부 작업 종료 보장은 아니다.
                try await Task.sleep(for: .milliseconds(200))
                #expect(presentation.radioState == radioState)
                #expect(presentation.lapsState == lapsState)
                #expect(presentation.positionsState == positionsState)
                #expect(presentation.stintsState == stintsState)
            }
        }
    }
}

// MARK: - 입력과 자료별 기대값

private extension DriverRadioViewModelTests {
    var dataKinds: [RadioDataKind] { [.radio, .laps, .positions, .stints] }
    var selectedRace: Race {
        .init(sessionID: 99, season: 2026, name: "Test GP", startsAt: Date(timeIntervalSince1970: 500), location: "Circuit")
    }
    var selectedDriver: RaceDriver {
        .init(driverNumber: 7, name: "Driver", acronym: nil, teamName: nil,
              result: .init(position: 5, didNotFinish: true, didNotStart: false, isDisqualified: false))
    }
    var laps: [DriverLap] { [.init(number: 14, startsAt: Date(timeIntervalSince1970: 500), duration: 90)] }
    var positions: [DriverPosition] { [.init(recordedAt: Date(timeIntervalSince1970: 510), position: 2)] }
    var stints: [DriverStint] { [.init(startLap: 1, endLap: 20, compound: "SOFT")] }

    func radioRecords() throws -> [RadioRecord] {
        let firstURL = try #require(URL(string: "https://example.com/z.mp3"))
        let secondURL = try #require(URL(string: "https://example.com/a.mp3"))
        return [.init(recordedAt: Date(timeIntervalSince1970: 520), recordingURL: firstURL),
                .init(recordedAt: Date(timeIntervalSince1970: 530), recordingURL: secondURL)]
    }

    func complete(_ request: DriverRadioUseCaseSpy.Request, with result: Completion,
                  using useCase: DriverRadioUseCaseSpy) async throws {
        switch request.kind {
        case .radio:
            try await useCase.completeRadioRecords(request, with: response(result, content: try radioRecords()))
        case .laps:
            try await useCase.completeLaps(request, with: response(result, content: laps))
        case .positions:
            try await useCase.completePositions(request, with: response(result, content: positions))
        case .stints:
            try await useCase.completeStints(request, with: response(result, content: stints))
        }
    }

    func response<Value>(_ result: Completion, content: [Value]) -> Result<[Value], any Error> {
        switch result {
        case .content: .success(content)
        case .empty: .success([])
        case .failed: .failure(URLError(.timedOut))
        case .cancelled: .failure(CancellationError())
        }
    }

    func matches(_ result: Completion, for kind: RadioDataKind, in presentation: any DriverRadioPresentation) -> Bool {
        switch kind {
        case .radio:
            guard let records = try? radioRecords() else { return false }
            return presentation.radioState == state(result, content: records)
        case .laps: return presentation.lapsState == state(result, content: laps)
        case .positions: return presentation.positionsState == state(result, content: positions)
        case .stints: return presentation.stintsState == state(result, content: stints)
        }
    }

    func state<Value>(_ result: Completion, content: [Value]) -> RadioLoadState<[Value]> where Value: Equatable & Sendable {
        switch result {
        case .content: .loaded(content)
        case .empty: .loaded([])
        case .failed: .failed
        case .cancelled: .cancelled
        }
    }

    func isLoading(_ kind: RadioDataKind, in presentation: any DriverRadioPresentation) -> Bool {
        switch kind {
        case .radio: presentation.radioState == .loading
        case .laps: presentation.lapsState == .loading
        case .positions: presentation.positionsState == .loading
        case .stints: presentation.stintsState == .loading
        }
    }
}

// MARK: - 준비·정리와 비동기 상태 확인

private extension DriverRadioViewModelTests {
    func withPresentation(
        useCase: DriverRadioUseCaseSpy = DriverRadioUseCaseSpy(),
        _ test: (any DriverRadioPresentation, DriverRadioUseCaseSpy, RadioPlaybackSpy) async throws -> Void
    ) async throws {
        let playback = RadioPlaybackSpy()
        let presentation: any DriverRadioPresentation = DriverRadioViewModel(
            race: selectedRace, driver: selectedDriver, useCase: useCase, playback: playback)
        do {
            try await test(presentation, useCase, playback)
        } catch {
            presentation.leave()
            await useCase.close()
            throw error
        }
        presentation.leave()
        await useCase.close()
    }

    func loadRadio(in presentation: any DriverRadioPresentation, using useCase: DriverRadioUseCaseSpy) async throws -> [RadioRecord] {
        presentation.load()
        for kind in dataKinds { _ = try await useCase.request(kind) }
        let request = try await useCase.request(.radio)
        let records = try radioRecords()
        try await useCase.completeRadioRecords(request, with: .success(records))
        try await waitUntil { presentation.radioState == .loaded(records) }
        return records
    }

    func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(condition(), "예상한 화면 상태에 도달하지 않았습니다.")
    }
}

// MARK: - 매개변수 사례

extension DriverRadioViewModelTests {
    enum Completion: CaseIterable, Sendable { case content, empty, failed, cancelled }
}
