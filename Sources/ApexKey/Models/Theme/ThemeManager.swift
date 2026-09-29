import AppKit
import SwiftUI

// MARK: - Theme Manager

extension Notification.Name {
    static let globalThemeChanged = Notification.Name("globalThemeChanged")
}

@MainActor
public class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()

    @Published var currentTheme: ThemeProtocol
    @Published var chatTheme: ThemeProtocol
    @Published public private(set) var appearanceMode: AppearanceMode = .system
    @Published public private(set) var activeCustomTheme: CustomTheme?
    @Published public private(set) var installedThemes: [CustomTheme] = []

    public var isCustomThemeActive: Bool { activeCustomTheme != nil }

    nonisolated(unsafe) public private(set) static var fontScale: Double = 1.0
    private static let fontScaleStep: Double = 0.1

    public var canZoomFontIn: Bool {
        Self.fontScale < 2.0
    }
    public var canZoomFontOut: Bool {
        Self.fontScale > 0.5
    }
    public var isDefaultFontScale: Bool { Self.fontScale == 1.0 }

    public func zoomFontIn() { setFontScale(Self.fontScale + Self.fontScaleStep) }
    public func zoomFontOut() { setFontScale(Self.fontScale - Self.fontScaleStep) }
    public func resetFontScale() { setFontScale(1.0) }

    public func setFontScale(_ scale: Double, persist: Bool = true) {
        let snapped = (scale / Self.fontScaleStep).rounded() * Self.fontScaleStep
        let clamped = min(max(snapped, 0.5), 2.0)
        guard clamped != Self.fontScale else { return }
        Self.fontScale = clamped

        if persist {
            // PrefKeys 상수 — rawValue 동일 (E-MAC-UX-9009)
            UserDefaults.standard.set(clamped, forKey: ConfigStore.PrefKeys.fontScale)
        }

        if let custom = activeCustomTheme {
            let themeInstance = CustomizableTheme(config: custom)
            currentTheme = themeInstance
            chatTheme = themeInstance
        } else {
            applyResolvedTheme(for: appearanceMode, animated: false)
        }
        NotificationCenter.default.post(name: .globalThemeChanged, object: nil)
    }

    private init() {
        let savedScale = UserDefaults.standard.double(forKey: ConfigStore.PrefKeys.fontScale)
        Self.fontScale = savedScale > 0 ? savedScale : 1.0

        let savedThemeId = UserDefaults.standard.string(forKey: ConfigStore.PrefKeys.activeThemeId)
        let savedMode = UserDefaults.standard.string(forKey: ConfigStore.PrefKeys.appearanceMode) ?? "system"
        let appearanceMode = AppearanceMode(rawValue: savedMode) ?? .system

        if let themeId = savedThemeId, let uuid = UUID(uuidString: themeId),
           let custom = ThemeConfigurationStore.loadTheme(id: uuid) {
            self.activeCustomTheme = custom
            let themeInstance = CustomizableTheme(config: custom)
            self.currentTheme = themeInstance
            self.chatTheme = themeInstance
        } else {
            let fallbackTheme = Self.isDarkMode(for: appearanceMode) ? CustomTheme.darkDefault : CustomTheme.lightDefault
            let themeInstance = CustomizableTheme(config: fallbackTheme)
            self.currentTheme = themeInstance
            self.chatTheme = themeInstance
        }

        self.appearanceMode = appearanceMode
        self.installedThemes = []

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(systemAppearanceChanged),
            name: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemAccentColorChanged),
            name: NSColor.systemColorsDidChangeNotification,
            object: nil
        )

        Task { @MainActor [weak self] in
            self?.loadInstalledThemes()
        }
    }

    func loadInstalledThemes() {
        ThemeConfigurationStore.installBuiltInThemesIfNeeded()
        let loaded = ThemeConfigurationStore.listThemesFromDisk()

        self.installedThemes = loaded

        if self.activeCustomTheme == nil,
           let builtIn = Self.resolveBuiltInTheme(for: appearanceMode, from: loaded) {
            let themeInstance = CustomizableTheme(config: builtIn)
            self.currentTheme = themeInstance
            self.chatTheme = themeInstance
        }
    }

    static func resolveBuiltInTheme(for mode: AppearanceMode, from themes: [CustomTheme]) -> CustomTheme? {
        let targetId = isDarkMode(for: mode) ? UUID(uuidString: "00000000-0000-0000-0000-000000000001")! : UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        return themes.first { $0.metadata.id == targetId }
    }

    public func setAppearanceMode(
        _ mode: AppearanceMode,
        clearActiveTheme: Bool = false,
        persist: Bool = true
    ) {
        appearanceMode = mode

        if persist {
            UserDefaults.standard.set(mode.rawValue, forKey: ConfigStore.PrefKeys.appearanceMode)
        }
        if clearActiveTheme {
            activeCustomTheme = nil
            UserDefaults.standard.removeObject(forKey: ConfigStore.PrefKeys.activeThemeId)
        }

        guard activeCustomTheme == nil else { return }

        applyResolvedTheme(for: mode, animated: true)
        NotificationCenter.default.post(name: .globalThemeChanged, object: nil)
    }

    public func applyCustomTheme(_ theme: CustomTheme, persist: Bool = true, animated: Bool = true) {
        activeCustomTheme = theme
        if persist {
            UserDefaults.standard.set(theme.metadata.id.uuidString, forKey: ConfigStore.PrefKeys.activeThemeId)
        }

        let themeInstance = CustomizableTheme(config: theme)
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentTheme = themeInstance
                chatTheme = themeInstance
            }
        } else {
            currentTheme = themeInstance
            chatTheme = themeInstance
        }
        NotificationCenter.default.post(name: .globalThemeChanged, object: nil)
    }

    func clearCustomTheme(persist: Bool = true, animated: Bool = true) {
        activeCustomTheme = nil
        if persist {
            UserDefaults.standard.removeObject(forKey: ConfigStore.PrefKeys.activeThemeId)
        }

        applyResolvedTheme(for: appearanceMode, animated: animated)
        NotificationCenter.default.post(name: .globalThemeChanged, object: nil)
    }

    func refreshInstalledThemes() {
        installedThemes = ThemeConfigurationStore.listThemes()
    }

    func saveTheme(_ theme: CustomTheme) {
        ThemeConfigurationStore.saveTheme(theme)
        refreshInstalledThemes()

        if activeCustomTheme?.metadata.id == theme.metadata.id {
            applyCustomTheme(theme)
        } else {
            NotificationCenter.default.post(name: .globalThemeChanged, object: nil)
        }
    }

    @discardableResult
    func deleteTheme(id: UUID) -> Bool {
        if let theme = installedThemes.first(where: { $0.metadata.id == id }) {
            if theme.isBuiltIn { return false }
        }

        let success = ThemeConfigurationStore.deleteTheme(id: id)
        if success {
            refreshInstalledThemes()
            if activeCustomTheme?.metadata.id == id {
                clearCustomTheme()
            }
        }
        return success
    }

    func forceReinstallBuiltInThemes() {
        ThemeConfigurationStore.forceReinstallBuiltInThemes()
        refreshInstalledThemes()
    }

    static func isDarkMode(for mode: AppearanceMode) -> Bool {
        switch mode {
        case .system:
            if let app = NSApp, app.isRunning {
                return app.effectiveAppearance.name == .darkAqua
            } else {
                return UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
            }
        case .light: return false
        case .dark: return true
        }
    }

    @objc private func systemAppearanceChanged() {
        Task { @MainActor [weak self] in
            self?.applySystemAppearanceChange()
        }
    }

    private func applySystemAppearanceChange() {
        guard appearanceMode == .system, activeCustomTheme == nil else { return }
        applyResolvedTheme(for: .system, animated: true)
        NotificationCenter.default.post(name: .globalThemeChanged, object: nil)
    }

    @objc private func systemAccentColorChanged() {
        Task { @MainActor [weak self] in
            self?.applySystemAccentChange()
        }
    }

    private func applySystemAccentChange() {
        if let custom = activeCustomTheme {
            guard custom.followsSystemAccent else { return }
            applyCustomTheme(custom, persist: false)
            return
        }
        applyResolvedTheme(for: appearanceMode, animated: true)
        NotificationCenter.default.post(name: .globalThemeChanged, object: nil)
    }

    private func applyResolvedTheme(for mode: AppearanceMode, animated: Bool) {
        let resolvedTheme = Self.resolveBuiltInTheme(for: mode, from: installedThemes)
            ?? (Self.isDarkMode(for: mode) ? CustomTheme.darkDefault : CustomTheme.lightDefault)
        let themeInstance = CustomizableTheme(config: resolvedTheme)

        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentTheme = themeInstance
                chatTheme = themeInstance
            }
        } else {
            currentTheme = themeInstance
            chatTheme = themeInstance
        }
    }

    // MARK: - Chat Theme (for future per-agent theming)

    func applyChatTheme(_ theme: CustomTheme, animated: Bool = true) {
        let themeInstance = CustomizableTheme(config: theme)
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                chatTheme = themeInstance
            }
        } else {
            chatTheme = themeInstance
        }
    }

    func syncChatTheme(animated: Bool = true) {
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                chatTheme = currentTheme
            }
        } else {
            chatTheme = currentTheme
        }
    }
}
