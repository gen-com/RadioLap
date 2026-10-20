//
//  RaceDateLabelsTests.swift
//  RadioLapTests
//

import Foundation
import Testing

struct RaceDateLabelsTests {
    @Test("같은 절대 시각을 시간대에 맞는 날짜와 시간으로 표시한다",
          arguments: ["UTC", "Asia/Seoul", "America/Los_Angeles"])
    func displaysLocalDate(_ identifier: String) throws {
        // Arrange
        let date = try #require(ISO8601DateFormatter().date(from: "2026-01-01T00:30:00Z"))
        let zone = try #require(TimeZone(identifier: identifier))
        let expectedMonth = identifier == "America/Los_Angeles" ? "Dec" : "Jan"
        let expectedDay = identifier == "America/Los_Angeles" ? "31" : "01"
        let expectedTime = identifier == "UTC" ? "00:30" : identifier == "Asia/Seoul" ? "09:30" : "16:30"

        // Act
        let labels = RaceDateLabels(date: date, timeZone: zone, locale: Locale(identifier: "en_GB"))

        // Assert
        #expect(labels.month == expectedMonth)
        #expect(labels.day == expectedDay)
        #expect(labels.time == expectedTime)
        #expect(labels.fullDate.contains(identifier == "America/Los_Angeles" ? "2025" : "2026"))
    }

    @Test("서머타임 시작과 종료 시각에 해당 시간대 규칙을 적용한다", arguments: [
        ["2026-03-08T09:30:00Z", "01:30"],
        ["2026-03-08T10:30:00Z", "03:30"],
        ["2026-11-01T08:30:00Z", "01:30"],
        ["2026-11-01T09:30:00Z", "01:30"]
    ])
    func observesDaylightSaving(_ example: [String]) throws {
        // Arrange
        let date = try #require(ISO8601DateFormatter().date(from: example[0]))
        let zone = try #require(TimeZone(identifier: "America/Los_Angeles"))

        // Act
        let labels = RaceDateLabels(date: date, timeZone: zone, locale: Locale(identifier: "en_GB"))

        // Assert
        #expect(labels.time == example[1])
    }
}
