import Foundation
import SwiftData
import AppKit
import Combine

/// ConfigStore 영역 분할 (R-10) — 동일 클래스 extension, public API 동결.
extension ConfigStore {

    /// 매크로 녹화 시작
    func startMacroRecording() {
        MacroRecorder.shared.startRecording()
        isMacroRecording = true
        macroRecordedKeyCodes = []
    }

    /// 매크로 녹화 중지 — 녹화된 키코드들을 반환 (바인딩은 만들지 않음)
    func stopMacroRecording() -> [UInt32] {
        let keyCodes = MacroRecorder.shared.recordedKeyCodes
        MacroRecorder.shared.stopRecording()
        isMacroRecording = false
        macroRecordedKeyCodes = []
        Logger.info("ConfigStore", "매크로 녹화 중지 — \(keyCodes.count)개 키")
        return keyCodes
    }

    /// 녹화된 키코드를 지정한 단축키로 매크로 바인딩 등록
    func recordMacro(keyCodes: [UInt32], combo: HotKeyCombo) -> Bool {
        guard !keyCodes.isEmpty, !combo.isEmpty else { return false }
        let target = keyCodes.map { String($0) }.joined(separator: ",")
        let binding = HotKeyBinding(
            combo: combo,
            actionType: .macro,
            target: target,
            title: "macro.title_fmt".localizedFormat(keyCodes.count),
            onlyWhenAppActive: false
        )
        addBinding(binding)
        Logger.info("ConfigStore", "매크로 바인딩 추가: \(binding.title) (\(combo.displayString))")
        return true
    }
}
