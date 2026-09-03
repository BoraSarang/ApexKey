import Foundation
import AppKit
import Carbon.HIToolbox

/// 키보드 이벤트/코드 ↔ 단축키 조합 변환 유틸리티
enum KeyboardUtil {
    // Carbon modifier flags
    static let cmdMask: UInt32 = UInt32(cmdKey)          // 1<<8
    static let shiftMask: UInt32 = UInt32(shiftKey)      // 1<<9
    static let optionMask: UInt32 = UInt32(optionKey)    // 1<<11
    static let controlMask: UInt32 = UInt32(controlKey)  // 1<<12

    /// NSEvent를 HotKeyCombo로 변환
    static func combo(from event: NSEvent) -> HotKeyCombo {
        let keyCode = UInt32(event.keyCode)
        let modifiers = carbonModifiers(from: event.modifierFlags)
        let display = displayString(keyCode: keyCode, modifiers: modifiers)
        return HotKeyCombo(keyCode: keyCode, modifiers: modifiers, displayString: display)
    }

    /// NSEvent.ModifierFlags → Carbon modifier flags
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= cmdMask }
        if flags.contains(.shift) { result |= shiftMask }
        if flags.contains(.option) { result |= optionMask }
        if flags.contains(.control) { result |= controlMask }
        return result
    }

    /// 표시용 단축키 문자열 (예: "⌘⇧N")
    static func displayString(keyCode: UInt32, modifiers: UInt32) -> String {
        var parts: [String] = []
        if modifiers & cmdMask != 0 { parts.append("⌘") }
        if modifiers & shiftMask != 0 { parts.append("⇧") }
        if modifiers & optionMask != 0 { parts.append("⌥") }
        if modifiers & controlMask != 0 { parts.append("⌃") }
        parts.append(symbol(for: keyCode))
        return parts.joined()
    }

    /// Carbon virtual key code → 표시 문자
    static func symbol(for keyCode: UInt32) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "⏎"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "⇥"
        case 49: return "␣"
        case 50: return "`"
        case 51: return "⌫"
        case 53: return "⎋"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 105: return "F13"
        case 106: return "F16"
        case 107: return "F14"
        case 109: return "F10"
        case 111: return "F12"
        case 113: return "F15"
        case 114: return "Help"
        case 115: return "↖"
        case 116: return "PgUp"
        case 117: return "⌦"
        case 118: return "F4"
        case 119: return "End"
        case 120: return "F2"
        case 121: return "PgDn"
        case 122: return "F1"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "·"
        }
    }

    /// 단축키에 필요한 최소 1개 이상의 수식키가 있는지 (순수 문자키만으로는 글로벌 등록 지양)
    static func hasModifier(_ combo: HotKeyCombo) -> Bool {
        combo.modifiers != 0
    }

    /// 일반 문자(등록 대상 키) 판별 — Esc 등은 제외
    static func isUsableKeyCode(_ keyCode: UInt32) -> Bool {
        let excluded: Set<UInt32> = [36, 48, 49, 51, 53, 115, 116, 117, 119, 121, 123, 124, 125, 126]
        return !excluded.contains(keyCode)
    }
}
