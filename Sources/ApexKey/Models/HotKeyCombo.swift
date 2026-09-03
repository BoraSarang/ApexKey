import Foundation

/// 단축키 조합 표현 (Carbon keyCode + modifiers)
struct HotKeyCombo: Codable, Equatable, Hashable {
    var keyCode: UInt32   // Carbon virtual key code
    var modifiers: UInt32 // Carbon modifier flags
    var displayString: String

    init(keyCode: UInt32, modifiers: UInt32, displayString: String = "") {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayString = displayString.isEmpty ? "" : displayString
    }

    static let empty = HotKeyCombo(keyCode: 0, modifiers: 0)
    var isEmpty: Bool { keyCode == 0 && modifiers == 0 }

    /// 표시 문자열과 무관하게 단축키 조합(keyCode+modifiers)만으로 일치하는지
    func matches(_ other: HotKeyCombo) -> Bool {
        keyCode == other.keyCode && modifiers == other.modifiers
    }
}
