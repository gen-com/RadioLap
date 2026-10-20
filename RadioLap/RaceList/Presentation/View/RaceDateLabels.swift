//
//  RaceDateLabels.swift
//  RadioLap
//

import Foundation

/// 절대 시각을 표시 시점의 기기 시간대와 언어로 표현한다.
struct RaceDateLabels {
    let month: String
    let day: String
    let time: String
    let fullDate: String

    init(date: Date, timeZone: TimeZone, locale: Locale) {
        let style = Date.FormatStyle(locale: locale, timeZone: timeZone)
        month = date.formatted(style.month(.abbreviated))
        day = date.formatted(style.day(.twoDigits))
        time = date.formatted(style.hour().minute())
        fullDate = date.formatted(style.year().month().day().weekday().hour().minute())
    }
}
