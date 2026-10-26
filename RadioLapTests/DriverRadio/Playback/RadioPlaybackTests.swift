//
//  RadioPlaybackTests.swift
//  RadioLapTests
//

import Foundation
import Observation
import Testing

@MainActor
final class RadioPlaybackTests {

    // MARK: - 테스트: 초기 상태와 준비

    @Test("초기화는 오디오에 명령을 보내지 않고 위치·길이를 모르는 대기 상태로 시작한다")
    func startsIdle() {
        // Arrange / Act
        let transport = RadioAudioTransportSpy()
        let playback: any RadioPlayback = RadioPlayer(transport: transport)

        // Assert
        #expect(playback.state == .idle)
        #expect(playback.position == nil)
        #expect(playback.duration == nil)
        #expect(transport.commands.isEmpty)
    }

    @Test("재생 요청은 URL을 준비하고 준비 완료 뒤 재생을 요청하며 실제 시작 이벤트로 playing이 된다")
    func preparesThenPlays() async throws {
        // Arrange
        let transport = RadioAudioTransportSpy()
        let playback: any RadioPlayback = RadioPlayer(transport: transport)
        let url = try recordingURL()
        defer { playback.stop() }

        await confirmation("준비 상태 변경 알림") { changed in
            withObservationTracking { _ = playback.state } onChange: { changed() }
            // Act
            playback.play(url: url)
            // Assert
            #expect(playback.state == .preparing)
        }
        #expect(transport.commands.filter { $0 == .prepare(url) }.count == 1)
        #expect(!transport.commands.contains(.play))
        #expect(playback.position == nil)
        #expect(playback.duration == nil)

        // Act / Assert
        try transport.send(.ready)
        #expect(transport.commands.last == .play)
        #expect(playback.state == .preparing)
        try await confirmation("실제 재생 상태 변경 알림") { changed in
            withObservationTracking { _ = playback.state } onChange: { changed() }
            try transport.send(.playing)
            #expect(playback.state == .playing)
        }
    }

    @Test("준비 명령 안에서 도착한 준비 완료·실패도 현재 작업의 이벤트로 처리한다", arguments: [false, true])
    func handlesEventsDuringPrepare(_ fail: Bool) throws {
        // Arrange
        let transport = RadioAudioTransportSpy()
        transport.eventDuringPrepare = fail ? .failed : .ready
        let playback: any RadioPlayback = RadioPlayer(transport: transport)
        defer { playback.stop() }

        // Act
        playback.play(url: try recordingURL())

        // Assert
        #expect(playback.state == (fail ? .failed : .preparing))
        #expect(transport.commands.contains(.play) == !fail)
        if !fail {
            try transport.send(.playing)
            #expect(playback.state == .playing)
        }
    }

    // MARK: - 테스트: 진행 정보와 중단·재개

    @Test("위치·길이는 독립적인 정보 부재를 보존하고 관찰 가능하게 갱신하며 재생을 다시 시작하지 않는다")
    func publishesProgress() async throws {
        // Arrange
        let transport = RadioAudioTransportSpy()
        let playback: any RadioPlayback = RadioPlayer(transport: transport)
        defer { playback.stop() }
        playback.play(url: try recordingURL())
        try transport.send(.ready)
        try transport.send(.playing)
        let commands = transport.commands

        // Act / Assert: 둘 중 하나만 알려진 경우와 다시 모르게 된 경우를 구분한다.
        try await confirmation("위치 변경 알림") { changed in
            withObservationTracking { _ = playback.position } onChange: { changed() }
            try transport.send(.progress(position: 12, duration: nil))
            #expect(playback.position == 12)
            #expect(playback.duration == nil)
        }
        try await confirmation("길이 변경 알림") { changed in
            withObservationTracking { _ = playback.duration } onChange: { changed() }
            try transport.send(.progress(position: nil, duration: 30))
            #expect(playback.position == nil)
            #expect(playback.duration == 30)
        }
        try transport.send(.progress(position: nil, duration: nil))
        #expect(playback.position == nil)
        #expect(playback.duration == nil)
        #expect(playback.state == .playing)
        #expect(transport.commands == commands)
    }

    @Test("재생·데이터 대기 중 일시정지 후 사용자 재개는 추가 준비 알림 없이 같은 위치에서 이어 재생한다",
          arguments: [false, true])
    func resumesWithoutPreparingAgain(_ waiting: Bool) throws {
        // Arrange
        let transport = RadioAudioTransportSpy()
        let playback: any RadioPlayback = RadioPlayer(transport: transport)
        defer { playback.stop() }
        playback.play(url: try recordingURL())
        try transport.send(.ready)
        try transport.send(.playing)
        try transport.send(.progress(position: 12, duration: 30))
        if waiting { try transport.send(.waiting) }
        let commands = transport.commands

        // Act
        playback.pause()

        // Assert
        #expect(playback.state == .paused)
        #expect(playback.position == 12)
        #expect(playback.duration == 30)
        #expect(transport.commands == commands + [.pause])

        // Act / Assert
        playback.resume()
        #expect(transport.commands == commands + [.pause, .play])
        #expect(playback.position == 12)
        try transport.send(.playing)
        #expect(playback.state == .playing)
    }

    @Test("데이터 대기는 위치를 유지하며 재생 의도가 유지되면 준비 해소 후 이어 재생한다")
    func continuesAfterWaiting() throws {
        // Arrange
        let transport = RadioAudioTransportSpy()
        let playback: any RadioPlayback = RadioPlayer(transport: transport)
        let url = try recordingURL()
        defer { playback.stop() }
        playback.play(url: url)
        try transport.send(.ready)
        try transport.send(.playing)
        try transport.send(.progress(position: 12, duration: 30))
        let commandCount = transport.commands.count

        // Act / Assert
        try transport.send(.waiting)
        #expect(playback.state == .preparing)
        #expect(playback.position == 12)
        try transport.send(.ready)
        try transport.send(.playing)
        #expect(playback.state == .playing)
        #expect(playback.position == 12)
        #expect(playback.duration == 30)
        // 대기 해소 시 필요한 추가 play는 허용하되 새 준비·중단 명령을 요구하지 않는다.
        #expect(transport.commands.dropFirst(commandCount).allSatisfy { $0 == .play })
    }

    @Test("준비·재생·데이터 대기 중 중단은 실제 일시정지를 요청하고 늦은 이벤트로 자동 재개하지 않는다",
          arguments: Phase.allCases, Interruption.allCases)
    func interruptsWithoutAutomaticResume(_ phase: Phase, _ interruption: Interruption) throws {
        // Arrange
        let transport = RadioAudioTransportSpy()
        let playback: any RadioPlayback = RadioPlayer(transport: transport)
        defer { playback.stop() }
        playback.play(url: try recordingURL())
        if phase != .preparing {
            try transport.send(.ready)
            try transport.send(.playing)
            try transport.send(.progress(position: 12, duration: 30))
        }
        if phase == .waiting { try transport.send(.waiting) }
        let position = playback.position
        let duration = playback.duration
        let commandCount = transport.commands.count

        // Act
        switch interruption {
        case .pause: playback.pause()
        case .deactivate: playback.deactivate()
        case .external: try transport.send(.interrupted)
        }

        // Assert
        #expect(playback.state == .paused)
        #expect(playback.position == position)
        #expect(playback.duration == duration)
        #expect(transport.commands.dropFirst(commandCount) == [.pause])
        let interruptedCommands = transport.commands.count
        for event in [RadioAudioEvent.ready, .waiting, .playing, .ready] {
            try transport.send(event)
            #expect(playback.state == .paused)
            #expect(playback.position == position)
            #expect(playback.duration == duration)
        }
        #expect(transport.commands.dropFirst(interruptedCommands).allSatisfy { $0 == .pause })

        // Act: 자동 재개와 사용자의 명시적 재개를 구분한다.
        let beforeResume = transport.commands.count
        playback.resume()
        try transport.send(.ready)
        #expect(transport.commands.dropFirst(beforeResume).contains(.play))
        #expect(transport.commands.dropFirst(beforeResume).allSatisfy { $0 == .play })
        try transport.send(.playing)
        #expect(playback.state == .playing)
        #expect(playback.position == position)
    }

    // MARK: - 테스트: 종료·재시도와 작업 교체

    @Test("종료·실패 후 자동으로 다시 준비하지 않으며 사용자 재시도는 같은 URL을 처음부터 준비한다",
          arguments: [false, true])
    func restartsAfterCompletion(_ fail: Bool) throws {
        // Arrange
        let transport = RadioAudioTransportSpy()
        let playback: any RadioPlayback = RadioPlayer(transport: transport)
        let url = try recordingURL()
        defer { playback.stop() }
        playback.play(url: url)
        try transport.send(.ready)
        try transport.send(.playing)
        try transport.send(.progress(position: 30, duration: 30))
        let commandCount = transport.commands.count

        // Act
        try transport.send(fail ? .failed : .ended)

        // Assert: 자원 정리용 중지는 허용하며 자동 재생·준비는 금지한다.
        #expect(playback.state == (fail ? .failed : .ended))
        #expect(transport.commands.dropFirst(commandCount).allSatisfy { $0 == .stop || $0 == .pause })

        // Act / Assert
        playback.play(url: url)
        #expect(playback.state == .preparing)
        #expect(playback.position == nil)
        #expect(playback.duration == nil)
        #expect(transport.commands.filter { $0 == .prepare(url) }.count == 2)
        try transport.send(.ready, forPreparation: 1)
        try transport.send(.playing, forPreparation: 1)
        #expect(playback.state == .playing)
    }

    @Test("같은 URL 재시작도 새 작업이며 이전 콜백의 이벤트는 현재 재생에 영향을 주지 않는다",
          arguments: [false, true])
    func ignoresReplacedEvents(_ sameURL: Bool) throws {
        // Arrange
        let transport = RadioAudioTransportSpy()
        let playback: any RadioPlayback = RadioPlayer(transport: transport)
        defer { playback.stop() }
        let first = try recordingURL()
        let next = try recordingURL(sameURL ? "first" : "second")
        playback.play(url: first)
        try transport.send(.ready)
        try transport.send(.playing)
        try transport.send(.progress(position: 12, duration: 30))

        // Act
        playback.play(url: next)

        // Assert
        #expect(playback.state == .preparing)
        #expect(playback.position == nil)
        #expect(playback.duration == nil)
        #expect(transport.commands.last == .prepare(next))
        let commands = transport.commands
        for event in staleEvents {
            try transport.send(event, forPreparation: 0)
            #expect(playback.state == .preparing)
            #expect(playback.position == nil)
            #expect(playback.duration == nil)
            #expect(transport.commands == commands)
        }
        // 새 작업의 이벤트는 계속 받아들인다.
        try transport.send(.ready, forPreparation: 1)
        try transport.send(.playing, forPreparation: 1)
        #expect(playback.state == .playing)
    }

    @Test("중지는 준비·재생·대기 중 오디오에 전달하고 초기화하며 늦은 이벤트를 무시한다",
          arguments: Phase.allCases)
    func stopsAndIgnoresLateEvents(_ phase: Phase) throws {
        // Arrange
        let transport = RadioAudioTransportSpy()
        let playback: any RadioPlayback = RadioPlayer(transport: transport)
        playback.play(url: try recordingURL())
        defer { playback.stop() }
        if phase != .preparing {
            try transport.send(.ready)
            try transport.send(.playing)
            try transport.send(.progress(position: 12, duration: 30))
        }
        if phase == .waiting { try transport.send(.waiting) }
        let before = transport.commands

        // Act
        playback.stop()

        // Assert
        #expect(transport.commands == before + [.stop])
        #expect(playback.state == .idle)
        #expect(playback.position == nil)
        #expect(playback.duration == nil)
        let commands = transport.commands
        for event in staleEvents {
            try transport.send(event)
            #expect(playback.state == .idle)
            #expect(playback.position == nil)
            #expect(playback.duration == nil)
            #expect(transport.commands == commands)
        }
    }
}

// MARK: - 테스트 입력

private extension RadioPlaybackTests {
    func recordingURL(_ name: String = "first") throws -> URL {
        try #require(URL(string: "https://example.com/\(name).mp3"))
    }

    var staleEvents: [RadioAudioEvent] {
        [.ready, .waiting, .playing, .progress(position: 99, duration: 100), .ended, .failed, .interrupted]
    }
}

// MARK: - 매개변수 사례

extension RadioPlaybackTests {
    enum Phase: CaseIterable, Sendable { case preparing, playing, waiting }
    enum Interruption: CaseIterable, Sendable { case pause, deactivate, external }
}
