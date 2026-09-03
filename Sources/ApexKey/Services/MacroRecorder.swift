import Foundation
import AppKit
import ApplicationServices

/// 매크로 녹화기 — NSEvent 전역 모니터로 키 이벤트를 캡처
final class MacroRecorder {
    static let shared = MacroRecorder()

    var isRecording = false
    var recordedKeyCodes: [UInt32] = []

    private var keyDownMonitor: Any?

    private init() {}

    /// 녹화 시작
    func startRecording() {
        guard !isRecording else { return }
        recordedKeyCodes = []
        isRecording = true

        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        Logger.info("MacroRecorder", "녹화 시작")
    }

    /// 녹화 중지
    func stopRecording() {
        guard isRecording else { return }
        isRecording = false

        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }

        Logger.info("MacroRecorder", "녹화 중지 — \(recordedKeyCodes.count)개 키")
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let keyCode = UInt32(event.keyCode)
        recordedKeyCodes.append(keyCode)
        Logger.info("MacroRecorder", "이벤트 캡처: keyCode=\(keyCode)")
    }
}