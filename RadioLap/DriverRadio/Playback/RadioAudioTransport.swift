//
//  RadioAudioTransport.swift
//  RadioLap
//

import Foundation

/// 오디오 준비·제어 명령과 실제 연동 이벤트를 전달하는 최소 경계.
@MainActor
protocol RadioAudioTransport: AnyObject {
    /// 이전 오디오를 정리하고 새 URL을 처음부터 준비한다. 준비만으로 재생하지 않는다.
    /// 콜백은 이 준비 작업에 속하며 명령 호출 중에도 이벤트를 전달할 수 있다.
    /// 실패는 failed 이벤트로 전달하고 이전 작업의 이벤트를 새 콜백으로 바꾸지 않는다.
    func prepare(url: URL, onEvent: @escaping @MainActor @Sendable (RadioAudioEvent) -> Void)

    /// 현재 오디오를 재생한다. 일시정지 후에는 위치를 유지한다.
    func play()
    /// 실제 플레이어를 일시정지하며 대기 해소 뒤에도 이전 재생 명령이 계속되지 않게 한다.
    func pause()
    /// 현재 오디오와 관찰을 정리한다. 이미 전달 중인 이벤트의 소멸은 보장하지 않는다.
    func stop()
}

/// 준비 작업에 속한 연동 이벤트. 최신 작업 판정과 재생 의도는 정책 객체가 관리한다.
nonisolated enum RadioAudioEvent: Sendable {
    /// 최초 준비 완료 또는 데이터 대기 해소. 자동 재생 요청은 아니다.
    case ready
    case waiting
    case playing
    /// 해당 시점의 초 단위 위치·길이. nil은 미제공이며 부분 갱신을 뜻하지 않는다.
    case progress(position: TimeInterval?, duration: TimeInterval?)
    case ended
    case failed
    /// 일시정지가 필요한 외부 중단. 자동 재개는 하지 않는다.
    case interrupted
}
