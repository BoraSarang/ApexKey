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

    static let defaultQuickLauncherHotkey = HotKeyCombo(
        keyCode: 49, // Space
        modifiers: KeyboardUtil.optionMask | KeyboardUtil.cmdMask,
        displayString: "⌥⌘Space"
    )

    static let defaultMenuHUDHotkey = HotKeyCombo(
        keyCode: 1, // S
        modifiers: KeyboardUtil.shiftMask | KeyboardUtil.optionMask,
        displayString: "⇧⌥S"
    )
}
