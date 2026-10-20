//
//  RaceListState.swift
//  RadioLap
//

/// 목록·로딩·오류를 중복 보관하지 않는 화면 조회 상태.
enum RaceListState: Equatable {
    /// 최초 조회 전 또는 조회 취소 후.
    case idle
    /// 유효한 조회가 진행 중.
    case loading
    /// 시작 시각 내림차순, 동률은 식별자 오름차순인 비어 있지 않은 목록.
    case content([Race])
    /// 정상 조회했으나 표시할 레이스가 없음.
    case empty
    /// 조회 실패와 사용자 안내.
    case failed(message: String)
}
