//
//  OpenF1DriverRecordDTO.swift
//  RadioLap
//

import Foundation

/// 드라이버별 응답의 요청 대상 검증에 필요한 식별자 계약이다.
nonisolated protocol OpenF1DriverRecordDTO: Decodable, Sendable {
    var sessionKey: Int { get }
    var driverNumber: Int { get }
}

extension JSONDecoder {
    /// 라디오·랩·순위 DTO에 공통으로 적용하는 시차 포함 날짜 해석 설정이다.
    nonisolated static func driverRadioResponses() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: text)
            else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "유효한 ISO 8601 날짜가 필요합니다.") }
            return date
        }
        return decoder
    }
}
