import Foundation

/// 단축키 키캡 표시 방법 (Mac-Keycap-Studio 6종 이식 — PNG 없이 코드 렌더).
/// rawValue는 UserDefaults 영속용이라 변경 금지.
enum KeycapStyle: String, CaseIterable, Identifiable {
    case symbol = "symbol"               // 1. 기호만 (⌘ ⇧) — 기존 방식
    case upper = "upper"                 // 2. 대문자 약어 (CMD)
    case symbolUpper = "symbolUpper"     // 3. 기호+대문자 (추천)
    case lower = "lower"                 // 4. 소문자 (cmd)
    case symbolLower = "symbolLower"     // 5. 기호+소문자
    case inline = "inline"               // 6. 한 줄 병기 (cmd · ⌘)

    var id: String { rawValue }

    /// 설정 Picker 표시명 (ko/en — Localizable.strings)
    var displayName: String {
        switch self {
        case .symbol: return "settings.keycap.style.symbol".localized
        case .upper: return "settings.keycap.style.upper".localized
        case .symbolUpper: return "settings.keycap.style.symbolUpper".localized
        case .lower: return "settings.keycap.style.lower".localized
        case .symbolLower: return "settings.keycap.style.symbolLower".localized
        case .inline: return "settings.keycap.style.inline".localized
        }
    }

    /// UserDefaults 표준 저장소에서 현재값 읽기 (store 없는 뷰용 폴백).
    static var current: KeycapStyle {
        let raw = UserDefaults.standard.string(forKey: ConfigStore.PrefKeys.keycapStyle)
        return KeycapStyle(rawValue: raw ?? "") ?? .symbolUpper
    }
}
