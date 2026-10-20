//
//  Race.swift
//  RadioLap
//

import Foundation

/// 결승 목록과 상세 화면 진입에 사용하는 레이스 정보.
///
/// 화면 표시 문자열을 포함하지 않으며, 날짜와 시간의 표현은 Presentation에서 담당한다.
struct Race: Identifiable, Equatable, Sendable {
    /// 결승 세션의 고유 식별자. 레이스 선택 후 상세 데이터를 조회할 때 사용한다.
    let sessionID: Int

    /// 목록에 표시할 대회 이름. 예: "Singapore Grand Prix".
    let name: String

    /// 시간대와 무관한 결승 시작 시각. 대회 주말의 시작 시각과 구분한다.
    ///
    /// 최신순 정렬의 기준이며, 표시할 때 사용자 기기의 시간대를 적용한다.
    let startsAt: Date

    /// 개최 장소. 제공되지 않거나 원본이 빈 문자열인 경우 `nil`이다.
    let location: String?

    /// `Identifiable`이 사용하는 식별자. 결승 세션의 `sessionID`와 같다.
    var id: Int { sessionID }
}
