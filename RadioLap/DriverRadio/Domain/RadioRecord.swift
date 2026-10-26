//
//  RadioRecord.swift
//  RadioLap
//

import Foundation

/// 공개된 교신의 기록 시각과 원격 오디오 주소.
nonisolated struct RadioRecord: Identifiable, Equatable, Sendable {
    /// 라디오 기록의 절대 시각. 실제 발화 시각과 차이가 있을 수 있다.
    let recordedAt: Date

    /// 호스트가 있는 HTTP·HTTPS 주소. 실제 접속·재생 가능 여부는 별도이다.
    let recordingURL: URL

    /// 한 세션·드라이버의 목록에서 기록 시각과 URL 문자열로 계산한 식별자.
    var id: RadioRecordID {
        RadioRecordID(recordedAt: recordedAt, recordingURLString: recordingURL.absoluteString)
    }
}
