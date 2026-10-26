//
//  RadioRecordID.swift
//  RadioLap
//

import Foundation

/// 한 세션·드라이버의 라디오 목록 안에서 교신을 구별한다.
nonisolated struct RadioRecordID: Hashable, Sendable {
    /// 라디오 기록의 절대 시각. 실제 발화 시각을 보장하지 않는다.
    let recordedAt: Date

    /// 검증한 오디오 URL의 문자열 표현. 경로·쿼리를 임의 정규화하지 않는다.
    let recordingURLString: String
}
