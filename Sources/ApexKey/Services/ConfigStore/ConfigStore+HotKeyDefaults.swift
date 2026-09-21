import Foundation
import SwiftData
import AppKit
import Combine

/// ConfigStore 영역 분할 (R-10) — 동일 클래스 extension, public API 동결.
extension ConfigStore {
    static let defaultToggleHotkey = HotKeyCombo(
        keyCode: 0, // A
        modifiers: KeyboardUtil.shiftMask | KeyboardUtil.optionMask,
        displayString: "⇧⌥A"
    )

    static let defaultRepeatHotkey = HotKeyCombo(
        keyCode: 36, // Return
        modifiers: KeyboardUtil.cmdMask | KeyboardUtil.shiftMask,
        displayString: "⌘⇧↩"
    )

    /// 명령 팔레트 기본값 — ⌘⌥K (전역 등록이므로 타 앱의 동일 조합을 가로챔. 설정에서 변경 가능).
    static let defaultPaletteHotkey = HotKeyCombo(
        keyCode: 40, // K
        modifiers: KeyboardUtil.cmdMask | KeyboardUtil.optionMask,
        displayString: "⌘⌥K"
    )

    static let defaultMenuHUDHotkey = HotKeyCombo(
        keyCode: 1, // S
        modifiers: KeyboardUtil.shiftMask | KeyboardUtil.optionMask,
        displayString: "⇧⌥S"
    )
}
