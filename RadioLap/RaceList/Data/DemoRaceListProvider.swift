//
//  DemoRaceListProvider.swift
//  RadioLap
//

import Foundation

/// 네트워크 없이 저장된 JSON에서 종료된 결승을 제공한다. 
struct DemoRaceListProvider: RaceListRepository {
    enum ResourceError: Error, Equatable {
        case missingFile(String)
    }

    private let meetingsURL: URL?
    private let sessionsURL: URL?
    private let mapper = RaceListResponseMapper()

    /// - Parameter bundle: JSON을 포함한 번들. 앱은 .main, 호스트 없는 테스트는 테스트 번들을 전달한다.
    init(bundle: Bundle) {
        meetingsURL = bundle.url(forResource: "meetings", withExtension: "json")
        sessionsURL = bundle.url(forResource: "sessions", withExtension: "json")
    }

    /// - Parameters:
    ///   - meetingsURL: 대회 JSON 파일 위치.
    ///   - sessionsURL: 세션 JSON 파일 위치.
    init(meetingsURL: URL, sessionsURL: URL) {
        self.meetingsURL = meetingsURL
        self.sessionsURL = sessionsURL
    }

    /// 저장된 JSON 두 개를 읽고 Repository 조건을 적용한다.
    /// - Parameters:
    ///   - year: 조회할 시즌 연도.
    ///   - endedBefore: 종료 시각의 상한. 동일 시각은 제외한다.
    /// - Returns: 중복 없는 결승 목록. 반환 순서는 보장하지 않는다.
    /// - Throws: 리소스 누락·파일 읽기·JSON 해석·데이터 연결 오류 또는 CancellationError.
    func fetchRaces(year: Int, endedBefore: Date) async throws -> [Race] {
        guard let meetingsURL else { throw ResourceError.missingFile("meetings.json") }
        guard let sessionsURL else { throw ResourceError.missingFile("sessions.json") }
        
        let meetingsData = try Data(contentsOf: meetingsURL)
        try Task.checkCancellation()
        
        let sessionsData = try Data(contentsOf: sessionsURL)
        try Task.checkCancellation()
        
        return try mapper.races(
            meetingsData: meetingsData, sessionsData: sessionsData,
            year: year, endedBefore: endedBefore
        )
    }
}
