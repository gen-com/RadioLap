//
//  Race.swift
//  RadioLap
//

import Foundation

/// 결승 목록과 상세 화면 진입에 사용하는 레이스 정보.
nonisolated struct Race: Identifiable, Equatable, Sendable {
    /// 결승 세션의 고유 식별자. 레이스 선택 후 상세 데이터를 조회할 때 사용한다.
    let sessionID: Int

    /// 목록에서 조회 시즌·연결 대회와 일치함을 검증한 세션의 시즌. 날짜에서 계산하지 않는다.
    let season: Int

    /// 목록에 표시할 대회 이름.
    let name: String

    /// 최신순 정렬의 기준인 결승 시작 절대 시각. 표시할 때 기기 시간대를 적용한다.
    let startsAt: Date

    /// 개최 장소. 정보가 없거나 빈 문자열이거나, 후보 간 장소가 충돌하면 nil이다.
    let location: String?

    /// `Identifiable`이 사용하는 식별자. 결승 세션의 `sessionID`와 같다.
    var id: Int { sessionID }
}
