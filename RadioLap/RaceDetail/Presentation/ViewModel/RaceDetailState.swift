//
//  RaceDetailState.swift
//  RadioLap
//

import Foundation

/// 레이스 기본 정보와 별도로 표시하는 드라이버 영역의 조회 상태.
enum RaceDetailState: Equatable {
    /// 최초 조회 전. 초기화만으로 조회하지 않는다.
    case idle
    /// 유효한 조회가 진행 중.
    case loading
    /// 표시 순서로 정렬된 비어 있지 않은 드라이버 그룹들.
    case content([RaceDriverGroup])
    /// 정상 조회했으나 참가자가 없음.
    case empty
    /// 조회 실패. 고정 안내와 다시 시도 동작을 제공한다.
    case failed
    /// 조회 취소. 오류 안내 없이 다시 불러오기 동작을 제공한다.
    case cancelled
}
