import Foundation
import SwiftData
import AppKit
import Combine

/// ConfigStore 영역 분할 (R-10) — 동일 클래스 extension, public API 동결.
extension ConfigStore {
    /// Menu HUD 표시 방식
    enum MenuHUDStyle: String, CaseIterable, Identifiable {
        case floatingWindow = "floatingWindow"
        case fullscreen = "fullscreen"
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .floatingWindow: return "settings.menu_hud.style.floating".localized
            case .fullscreen: return "settings.menu_hud.style.fullscreen".localized
            }
        }
    }

    enum PrefKeys {
        static let alwaysOnTop = "pref.alwaysOnTop"
        // ThemeManager 등 기존 하드코드 키 rawValue 유지 (E-MAC-UX-9009)
        static let fontScale = "ApexKeyFontScale"
        static let activeThemeId = "ApexKeyActiveThemeId"
        static let appearanceMode = "ApexKeyAppearanceMode"
        static let showInMenuBar = "pref.showInMenuBar"
        static let showInDock = "pref.showInDock"
        static let menuHUDStyle = "pref.menuHUDStyle"
        static let showNoShortcutItems = "pref.showNoShortcutItems"
        static let showSystemApps = "pref.showSystemApps"
        static let appLanguage = "pref.appLanguage"
        static let showSuccessToast = "pref.showSuccessToast"
        static let didSeedSamples = "pref.didSeedSamples"
        static let didCleanupLegacyAndroid = "pref.didCleanupLegacyAndroid"
        static let panelToggleHotkey = "pref.panelToggleHotkey"
        static let paletteHotkey = "pref.paletteHotkey"
        static let menuHUDHotkey = "pref.menuHUDHotkey"
        static let updateFrequency = "pref.updateFrequency"
        static let updateLastChecked = "pref.updateLastChecked"
        static let didMigrateLegacyStore = "pref.didMigrateLegacyStore"
    }

    /// HotKeyCombo UserDefaults 영속화 ("keyCode:modifiers:displayString")
    static func loadHotkey(forKey key: String, fallback: HotKeyCombo) -> HotKeyCombo {
        guard let raw = UserDefaults.standard.string(forKey: key) else { return fallback }
        let parts = raw.components(separatedBy: ":")
        guard parts.count >= 2, let kc = UInt32(parts[0]), let mod = UInt32(parts[1]) else { return fallback }
        let display = parts.count >= 3 ? parts[2...].joined(separator: ":") : ""
        let combo = HotKeyCombo(keyCode: kc, modifiers: mod, displayString: display)
        return combo.isEmpty ? fallback : combo
    }

    static func saveHotkey(_ combo: HotKeyCombo, forKey key: String) {
        UserDefaults.standard.set("\(combo.keyCode):\(combo.modifiers):\(combo.displayString)", forKey: key)
    }

    /// Menu HUD 표시 방식 전환
    func setMenuHUDStyle(_ style: MenuHUDStyle) {
        menuHUDStyle = style
        Logger.info("ConfigStore", "[HUD] 표시 방식 변경: \(style.rawValue)")
    }

    /// 메뉴바 표시를 전환. Dock도 꺼져 있으면 접근 불가가 되므로 거부하고 false 반환.
    /// - Returns: 적용되면 true, 경고로 거부되면 false
    func setMenuBarVisible(_ visible: Bool) -> Bool {
        if !visible && !showInDock {
            return false
        }
        showInMenuBar = visible
        return true
    }

    /// Dock 표시 전환. (Dock이 켜지면 접근 경로가 생기므로 항상 허용)
    func setDockVisible(_ visible: Bool) {
        showInDock = visible
    }
}
