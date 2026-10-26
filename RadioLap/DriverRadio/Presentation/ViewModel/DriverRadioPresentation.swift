//
//  DriverRadioPresentation.swift
//  RadioLap
//

import Foundation
import Observation

/// 선택한 레이스·드라이버와 자료별 조회·교신 선택·재생의 관찰 가능한 상태를 제공한다.
@MainActor
protocol DriverRadioPresentation: AnyObject, Observable {
    /// 상세에서 전달받아 화면 수명 동안 보존하는 레이스.
    var race: Race { get }
    /// 상세에서 선택한 참가자. 최종 결과를 라디오 당시 상황으로 사용하지 않는다.
    var driver: RaceDriver { get }
    /// 공개 교신 조회 상태. 성공한 반환 순서를 유지한다.
    var radioState: RadioLoadState<[RadioRecord]> { get }
    /// 랩 조회 상태. 다른 자료와 독립적으로 변경한다.
    var lapsState: RadioLoadState<[DriverLap]> { get }
    /// 순위 조회 상태. 다른 자료와 독립적으로 변경한다.
    var positionsState: RadioLoadState<[DriverPosition]> { get }
    /// 스틴트 조회 상태. 다른 자료와 독립적으로 변경한다.
    var stintsState: RadioLoadState<[DriverStint]> { get }
    /// 펼친 교신 하나의 식별자. 최초에는 nil이며 자동 선택하지 않는다.
    var selectedRadioID: RadioRecordID? { get }
    /// 재생 담당 객체가 제공하는 현재 상태.
    var playbackState: RadioPlaybackState { get }
    /// 확인된 재생 경과 시간(초). 모르면 nil이다.
    var playbackPosition: TimeInterval? { get }
    /// 확인된 전체 길이(초). 모르면 nil이다.
    var playbackDuration: TimeInterval? { get }

    /// 최초 네 조회를 독립적으로 시작한다. 반복 호출로 재조회하지 않는다.
    func load()
    /// 실패·취소된 지정 자료만 재요청하고 다른 자료·선택·재생은 유지한다.
    func retry(_ data: RadioDataKind)
    /// 같은 교신은 접고 다른 교신은 선택하며 기존 재생을 중지·초기화한다.
    /// 목록에 없는 식별자는 무시하고 자동 재생하지 않는다.
    func selectRadio(_ id: RadioRecordID)
    /// 선택한 교신을 재생한다. 일시정지는 재개하고 실패·종료는 처음부터 시작한다.
    /// 선택 없음·준비 중·재생 중에는 요청하지 않는다.
    func play()
    /// 재생 담당 객체에 위치를 보존하는 일시정지를 전달한다.
    func pause()
    /// 앱 비활성화를 전달한다. 화면의 조회 자료와 선택은 유지한다.
    func deactivate()
    /// 조회를 취소·무효화하고 재생을 중지·초기화한다. 작업 종료를 기다리지 않는다.
    func leave()
    /// 현재 교신의 기록 시각과 성공 자료로 동기 계산한다. 목록에 없을 때만 nil이다.
    /// 조회·선택·재생을 변경하지 않으며 성공 자료 미준비는 nil, 정상 빈 자료는 []로 전달한다.
    func context(for id: RadioRecordID) -> RadioContext?
}
