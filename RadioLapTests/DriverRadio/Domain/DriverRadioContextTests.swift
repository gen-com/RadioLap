//
//  DriverRadioContextTests.swift
//  RadioLapTests
//

import Foundation
import Testing

@MainActor
final class DriverRadioContextTests {

    // MARK: - 테스트: 자료 부재와 랩 연결

    @Test("성공 자료 미준비와 정상 빈 자료를 항목별로 구분한다")
    func distinguishesNotLoadedFromEmpty() {
        // Arrange: 공급자를 호출하면 기본 대역이 실패를 기록한다.
        let useCase = useCase()

        // Act
        let notLoaded = useCase.resolveContext(recordedAt: time(0), laps: nil, positions: nil, stints: nil)
        let empty = useCase.resolveContext(recordedAt: time(0), laps: [], positions: [], stints: [])

        // Assert
        #expect(notLoaded == RadioContext(lap: .notLoaded, position: .notLoaded, tyre: .lapUnavailable))
        #expect(empty == RadioContext(lap: .unavailable, position: .unavailable, tyre: .lapUnavailable))
    }

    @Test("랩 시작은 현재 구간에 포함하고 종료는 마지막 완료 랩으로 구분한다",
          arguments: [-1.0, 0.0, 89.0, 90.0, 100.0])
    func appliesLapBoundaries(_ seconds: Double) {
        // Arrange
        let useCase = useCase()
        let laps = [lap(14, start: 0, duration: 90)]
        let expected: LapContext = seconds < 0 ? .unavailable
            : seconds < 90 ? .current(number: 14, startsAt: time(0), endsAt: time(90))
            : .lastCompleted(number: 14, endsAt: time(90))

        // Act
        let actual = useCase.resolveContext(recordedAt: time(seconds), laps: laps, positions: [], stints: [])

        // Assert
        #expect(actual.lap == expected)
    }

    @Test("이전 랩 종료 시각에 시작하는 현재 랩을 우선한다", arguments: [false, true])
    func prefersCurrentLap(_ reversed: Bool) {
        // Arrange
        let laps = [lap(14, start: 0, duration: 90), lap(15, start: 90, duration: 80)]
        let useCase = useCase()

        // Act
        let actual = useCase.resolveContext(recordedAt: time(90),
            laps: reversed ? Array(laps.reversed()) : laps, positions: [], stints: [])

        // Assert
        #expect(actual.lap == .current(number: 15, startsAt: time(90), endsAt: time(170)))
    }

    @Test("랩 공백과 모든 구간 이후에는 가장 최근 종료 랩과 근거 시각을 제공한다",
          arguments: [100.0, 10_000.0], [false, true])
    func findsLastCompletedLap(_ seconds: Double, _ reversed: Bool) {
        // Arrange: 늦게 시작한 20랩은 먼저 끝난다. 번호·시작순·입력순 대신 종료 시각으로 고른다.
        let laps = [lap(20, start: 50, duration: 20), lap(14, start: 0, duration: 90),
                    lap(15, start: 110, duration: 80)]
        let useCase = useCase()
        let expected: LapContext = seconds < 110
            ? .lastCompleted(number: 14, endsAt: time(90))
            : .lastCompleted(number: 15, endsAt: time(190))

        // Act
        let actual = useCase.resolveContext(recordedAt: time(seconds),
            laps: reversed ? Array(laps.reversed()) : laps, positions: [], stints: [])

        // Assert
        #expect(actual.lap == expected)
    }

    @Test("현재 구간 겹침과 최신 종료 시각 동률은 임의 선택이나 이전 랩 대체 없이 충돌이다",
          arguments: [false, true])
    func reportsLapConflicts(_ reversed: Bool) {
        // Arrange
        let cases = [
            [lap(13, start: -100, duration: 50), lap(14, start: 0, duration: 90), lap(15, start: 20, duration: 90)],
            [lap(13, start: -100, duration: 50), lap(14, start: 0, duration: 40), lap(15, start: 10, duration: 30)]
        ]
        let useCase = useCase()
        for laps in cases {
            // Act
            let actual = useCase.resolveContext(recordedAt: time(50),
                laps: reversed ? Array(laps.reversed()) : laps, positions: [], stints: [])

            // Assert
            #expect(actual.lap == .conflicting)
            #expect(actual.tyre == .lapUnavailable)
        }
    }

    @Test("구간을 구성할 수 없는 랩은 현재·마지막 후보에서 제외하며 다음 시작으로 보충하지 않는다",
          arguments: [50.0, 200.0, Double.greatestFiniteMagnitude])
    func excludesInvalidIntervals(_ seconds: Double) {
        // Arrange
        let overflowStart = Date(timeIntervalSinceReferenceDate: .greatestFiniteMagnitude)
        // 종료 시각이 무한대가 되는 랩도 시작 시각에 연결을 시도해야 잘못된 구간 채택을 발견한다.
        let recordedAt = seconds == .greatestFiniteMagnitude ? overflowStart : time(seconds)
        let invalid: [DriverLap] = [
            .init(number: 1, startsAt: nil, duration: 90),
            .init(number: 2, startsAt: time(0), duration: nil),
            .init(number: 3, startsAt: time(40), duration: 0),
            .init(number: 4, startsAt: time(40), duration: -1),
            .init(number: 5, startsAt: overflowStart,
                  duration: .greatestFiniteMagnitude)]
        let valid = lap(6, start: 100, duration: 90)
        let useCase = useCase()

        // Act
        let alone = useCase.resolveContext(recordedAt: recordedAt, laps: invalid, positions: [], stints: [])
        let mixed = useCase.resolveContext(recordedAt: recordedAt, laps: invalid + [valid], positions: [], stints: [])

        // Assert
        #expect(alone.lap == .unavailable)
        #expect(mixed.lap == (seconds < 100 ? .unavailable : .lastCompleted(number: 6, endsAt: time(190))))
    }

    // MARK: - 테스트: 순위 연결

    @Test("순위는 랩·타이어와 독립적으로 이전 또는 같은 시각의 최신 기록과 근거를 제공한다",
          arguments: [-1.0, 0.0, 19.0, 20.0, 1_000_000.0], [false, true])
    func linksPositionIndependently(_ seconds: Double, _ reversed: Bool) {
        // Arrange
        let positions = [DriverPosition(recordedAt: time(0), position: 3),
                         DriverPosition(recordedAt: time(20), position: 1)]
        let expected: PositionContext = seconds < 0 ? .unavailable
            : seconds < 20 ? .recorded(position: 3, recordedAt: time(0))
            : .recorded(position: 1, recordedAt: time(20))
        let useCase = useCase()

        // Act
        let actual = useCase.resolveContext(recordedAt: time(seconds), laps: nil,
            positions: reversed ? Array(positions.reversed()) : positions, stints: nil)

        // Assert
        #expect(actual == RadioContext(lap: .notLoaded, position: expected, tyre: .lapUnavailable))
    }

    // MARK: - 테스트: 타이어 연결과 사유

    @Test("타이어 범위는 양쪽 끝 랩을 포함하고 범위 밖은 정보 없음이다", arguments: [9, 10, 20, 21])
    func appliesStintBoundaries(_ number: Int) {
        // Arrange
        let useCase = useCase()
        let stints = [DriverStint(startLap: 10, endLap: 20, compound: "SOFT")]
        let expected: TyreContext = (10...20).contains(number) ? .current(compound: "SOFT") : .unavailable

        // Act
        let actual = useCase.resolveContext(recordedAt: time(50),
            laps: [lap(number, start: 0, duration: 90)], positions: [], stints: stints)

        // Assert
        #expect(actual.tyre == expected)
    }

    @Test("같은 컴파운드 겹침은 연결하고 충돌·불완전·정보 없음은 우선순위로 구분한다",
          arguments: [false, true])
    func resolvesTyreReasons(_ reversed: Bool) {
        // Arrange: nil 컴파운드와 충돌이 함께 있으면 충돌이 우선이다.
        let soft = DriverStint(startLap: 1, endLap: 20, compound: "SOFT")
        let overlap = DriverStint(startLap: 10, endLap: 30, compound: "SOFT")
        let hard = DriverStint(startLap: 10, endLap: 30, compound: "HARD")
        let unknown = DriverStint(startLap: 10, endLap: 30, compound: nil)
        let outside = DriverStint(startLap: 30, endLap: 40, compound: nil)
        let cases: [([DriverStint], TyreContext)] = [
            ([], .unavailable), ([outside], .unavailable),
            ([soft, overlap], .current(compound: "SOFT")),
            ([soft, outside], .current(compound: "SOFT")),
            ([soft, hard], .conflicting), ([soft, hard, unknown], .conflicting),
            ([soft, unknown], .incomplete), ([unknown], .incomplete)]
        let useCase = useCase()
        for (stints, expected) in cases {
            // Act
            let actual = useCase.resolveContext(recordedAt: time(50),
                laps: [lap(14, start: 0, duration: 90)], positions: [],
                stints: reversed ? Array(stints.reversed()) : stints)

            // Assert
            #expect(actual.tyre == expected)
        }
    }

    @Test("범위 부재·역전은 영향 구간을 추정하지 않으며 다른 정상 타이어를 유지한다")
    func ignoresUnusableStintRanges() {
        // Arrange
        let invalid: [DriverStint] = [
            .init(startLap: nil, endLap: 20, compound: "HARD"),
            .init(startLap: 1, endLap: nil, compound: nil),
            .init(startLap: 20, endLap: 1, compound: "HARD")]
        let valid = DriverStint(startLap: 1, endLap: 20, compound: "NEW tyre")
        let useCase = useCase()

        // Act
        let alone = useCase.resolveContext(recordedAt: time(50),
            laps: [lap(14, start: 0, duration: 90)], positions: [], stints: invalid)
        let mixed = useCase.resolveContext(recordedAt: time(50),
            laps: [lap(14, start: 0, duration: 90)], positions: [], stints: invalid + [valid])

        // Assert
        #expect(alone.tyre == .unavailable)
        #expect(mixed.tyre == .current(compound: "NEW tyre"))
    }

    @Test("랩이 결정된 경우에만 스틴트 미준비를 구분하며 새 자료로 다시 연결할 수 있다")
    func resolvesAvailableStintsWithoutFetching() {
        // Arrange
        let useCase = useCase()
        let laps = [lap(14, start: 0, duration: 90)]
        let positions = [DriverPosition(recordedAt: time(10), position: 2)]
        let stints = [DriverStint(startLap: 1, endLap: 20, compound: "SOFT")]

        // Act: 같은 객체에 새 자료를 전달한다. 공급자 호출은 대역의 실패로 탐지한다.
        let before = useCase.resolveContext(recordedAt: time(100), laps: laps, positions: positions, stints: nil)
        let after = useCase.resolveContext(recordedAt: time(100), laps: laps, positions: positions, stints: stints)

        // Assert
        #expect(before == RadioContext(lap: .lastCompleted(number: 14, endsAt: time(90)),
            position: .recorded(position: 2, recordedAt: time(10)), tyre: .stintsNotLoaded))
        #expect(after == RadioContext(lap: .lastCompleted(number: 14, endsAt: time(90)),
            position: .recorded(position: 2, recordedAt: time(10)), tyre: .lastCompleted(compound: "SOFT")))
    }
}

// MARK: - 공통 준비

private extension DriverRadioContextTests {
    func useCase() -> any DriverRadioUseCase {
        DriverRadioInteractor(repository: DriverRadioRepositoryStub())
    }

    func time(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_800_000_000 + seconds)
    }

    func lap(_ number: Int, start: TimeInterval, duration: TimeInterval) -> DriverLap {
        .init(number: number, startsAt: time(start), duration: duration)
    }
}
