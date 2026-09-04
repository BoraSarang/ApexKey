import AppKit
import SwiftUI

// MARK: - Theme Protocol

protocol ThemeProtocol {
    // Primary colors
    var primaryText: Color { get }
    var secondaryText: Color { get }
    var tertiaryText: Color { get }
    var placeholderText: Color { get }

    // Background colors
    var primaryBackground: Color { get }
    var secondaryBackground: Color { get }
    var tertiaryBackground: Color { get }

    // Sidebar colors
    var sidebarBackground: Color { get }
    var sidebarSelectedBackground: Color { get }

    // Accent colors
    var accentColor: Color { get }
    var accentColorLight: Color { get }

    // Border colors
    var primaryBorder: Color { get }
    var secondaryBorder: Color { get }
    var focusBorder: Color { get }

    // Status colors
    var successColor: Color { get }
    var warningColor: Color { get }
    var errorColor: Color { get }
    var infoColor: Color { get }

    // Component specific
    var cardBackground: Color { get }
    var cardBorder: Color { get }
    var buttonBackground: Color { get }
    var buttonBorder: Color { get }
    var inputBackground: Color { get }
    var inputBorder: Color { get }
    var glassTintOverlay: Color { get }
    var codeBlockBackground: Color { get }

    // Selection (text highlight)
    var selectionColor: Color { get }

    // Cursor
    var cursorColor: Color { get }

    // Appearance
    var isDark: Bool { get }

    // Glass specific
    var glassEnabled: Bool { get }
    var glassSidebarEnabled: Bool { get }
    var glassInputEnabled: Bool { get }
    var glassMaterial: NSVisualEffectView.Material { get }
    var glassTintColor: Color? { get }
    var glassTintOpacity: Double { get }
    var glassOpacityPrimary: Double { get }
    var glassOpacitySecondary: Double { get }
    var glassOpacityTertiary: Double { get }
    var glassBlurRadius: Double { get }
    var glassEdgeLight: Color { get }
    var windowBackingOpacity: Double { get }

    // Card shadows (enhanced)
    var cardShadowRadius: Double { get }
    var cardShadowRadiusHover: Double { get }
    var cardShadowY: Double { get }
    var cardShadowYHover: Double { get }

    // Animation timing
    var animationDurationQuick: Double { get }
    var animationDurationMedium: Double { get }
    var animationDurationSlow: Double { get }
    var animationSpringResponse: Double { get }
    var animationSpringDamping: Double { get }
    var animationSpring: Animation { get }

    // Shadows
    var shadowColor: Color { get }
    var shadowOpacity: Double { get }

    // Background customization
    var backgroundImage: NSImage? { get }
    var backgroundImageOpacity: Double { get }
    var backgroundOverlayColor: Color? { get }
    var backgroundOverlayOpacity: Double { get }

    // Typography
    var primaryFontName: String { get }
    var monoFontName: String { get }
    var titleSize: Double { get }
    var headingSize: Double { get }
    var bodySize: Double { get }
    var captionSize: Double { get }
    var codeSize: Double { get }

    // Code syntax highlighting theme (Highlightr name). nil = auto.
    var codeHighlightTheme: String? { get }

    // Custom theme reference (for editing)
    var customThemeConfig: CustomTheme? { get }

    // Message bubble customization
    var bubbleCornerRadius: Double { get }
    var userBubbleOpacity: Double { get }
    var assistantBubbleOpacity: Double { get }
    var userBubbleColor: Color? { get }
    var assistantBubbleColor: Color? { get }
    var messageBorderWidth: Double { get }
    var showEdgeLight: Bool { get }
    var showInlineAvatar: Bool { get }
    var inlineAvatarSize: Double { get }
    var showAgentName: Bool { get }
    var agentNameSize: Double { get }

    // Border customization
    var defaultBorderWidth: Double { get }
    var cardCornerRadius: Double { get }
    var inputCornerRadius: Double { get }
    var borderOpacity: Double { get }
}

// MARK: - Default Protocol Extensions

extension ThemeProtocol {
    var glassEnabled: Bool { false }
    var glassSidebarEnabled: Bool { false }
    var glassInputEnabled: Bool { false }
    var glassMaterial: NSVisualEffectView.Material { .hudWindow }
    var glassTintColor: Color? { nil }
    var glassTintOpacity: Double { 0 }
    var windowBackingOpacity: Double { 0.55 }

    var backgroundImage: NSImage? { nil }
    var backgroundImageOpacity: Double { 1.0 }
    var backgroundOverlayColor: Color? { nil }
    var backgroundOverlayOpacity: Double { 0 }

    var primaryFontName: String { "SF Pro" }
    var monoFontName: String { "SF Mono" }
    var titleSize: Double { 28 }
    var headingSize: Double { 18 }
    var bodySize: Double { 14 }
    var captionSize: Double { 12 }
    var codeSize: Double { 13 }

    var codeHighlightTheme: String? { nil }
    var customThemeConfig: CustomTheme? { nil }

    var bubbleCornerRadius: Double { 20 }
    var userBubbleOpacity: Double { 0.3 }
    var assistantBubbleOpacity: Double { 0.85 }
    var userBubbleColor: Color? { nil }
    var assistantBubbleColor: Color? { nil }
    var messageBorderWidth: Double { 0.5 }
    var showEdgeLight: Bool { true }
    var showInlineAvatar: Bool { true }
    var inlineAvatarSize: Double { 24 }
    var showAgentName: Bool { true }
    var agentNameSize: Double { 13 }

    var defaultBorderWidth: Double { 1.0 }
    var cardCornerRadius: Double { 12 }
    var inputCornerRadius: Double { 8 }
    var borderOpacity: Double { 0.3 }

    // MARK: - Font Helpers

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if primaryFontName.lowercased().contains("sf pro") || primaryFontName.isEmpty {
            return .system(size: size, weight: weight)
        }
        return .custom(primaryFontName, size: size).weight(weight)
    }

    func monoFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if monoFontName.lowercased().contains("sf mono") || monoFontName.isEmpty {
            return .system(size: size, weight: weight, design: .monospaced)
        }
        return .custom(monoFontName, size: size).weight(weight)
    }

    // MARK: - Animation Helpers

    func animationQuick() -> Animation {
        .easeInOut(duration: animationDurationQuick)
    }

    func animationMedium() -> Animation {
        .easeInOut(duration: animationDurationMedium)
    }

    func animationSlow() -> Animation {
        .easeInOut(duration: animationDurationSlow)
    }

    func springAnimation() -> Animation {
        .spring(response: animationSpringResponse, dampingFraction: animationSpringDamping)
    }

    func springAnimation(responseMultiplier: Double = 1.0, dampingMultiplier: Double = 1.0) -> Animation {
        .spring(
            response: animationSpringResponse * responseMultiplier,
            dampingFraction: min(1.0, animationSpringDamping * dampingMultiplier)
        )
    }
}

// MARK: - Light Theme

struct LightTheme: ThemeProtocol {
    // Primary colors - Warm, rich blacks (WCAG AA compliant)
    let primaryText = Color(hex: "1a1a18")
    let secondaryText = Color(hex: "555550")
    let tertiaryText = Color(hex: "717168")
    let placeholderText = Color(hex: "555550")

    // Background colors - Warm whites with depth
    let primaryBackground = Color(hex: "ffffff")
    let secondaryBackground = Color(hex: "f9f9f7")
    let tertiaryBackground = Color(hex: "f2f2ef")

    // Sidebar colors - Warm and inviting
    let sidebarBackground = Color(hex: "f7f7f5")
    let sidebarSelectedBackground = Color(hex: "eaeae6")

    // Accent colors - Rich warm black
    let accentColor = Color(hex: "1a1a18")
    let accentColorLight = Color(hex: "3d3d3a")

    // Border colors
    let primaryBorder = Color(hex: "d0d0cc")
    let secondaryBorder = Color(hex: "e0e0dc")
    let focusBorder = Color(hex: "4a4a46")

    // Status colors
    let successColor = Color(hex: "15803d")
    let warningColor = Color(hex: "a16207")
    let errorColor = Color(hex: "dc2626")
    let infoColor = Color(hex: "555550")

    // Component specific
    let cardBackground = Color(hex: "ffffff")
    let cardBorder = Color(hex: "d0d0cc")
    let buttonBackground = Color(hex: "1a1a18")
    let buttonBorder = Color(hex: "1a1a18")
    let inputBackground = Color(hex: "ffffff")
    let inputBorder = Color(hex: "a8a8a3")
    let glassTintOverlay = Color(hex: "f5f5f2").opacity(0.6)
    let codeBlockBackground = Color(hex: "f5f5f2")

    let selectionColor = Color(hex: "3b82f6").opacity(0.3)
    let cursorColor = Color(hex: "1a1a18")

    // Glass specific
    let glassOpacityPrimary: Double = 0.25
    let glassOpacitySecondary: Double = 0.18
    let glassOpacityTertiary: Double = 0.10
    let glassBlurRadius: Double = 24
    let glassEdgeLight = Color.white.opacity(0.5)

    let cardShadowRadius: Double = 12
    let cardShadowRadiusHover: Double = 20
    let cardShadowY: Double = 3
    let cardShadowYHover: Double = 8

    let animationDurationQuick: Double = 0.2
    let animationDurationMedium: Double = 0.3
    let animationDurationSlow: Double = 0.4
    let animationSpringResponse: Double = 0.4
    let animationSpringDamping: Double = 0.8
    var animationSpring: Animation {
        .spring(response: animationSpringResponse, dampingFraction: animationSpringDamping)
    }

    let shadowColor = Color(hex: "8e8e93")
    let shadowOpacity: Double = 0.08

    let isDark = false
}

// MARK: - Dark Theme

struct DarkTheme: ThemeProtocol {
    // Primary colors - Warm off-white (WCAG AA compliant)
    let primaryText = Color(hex: "f5f5f2")
    let secondaryText = Color(hex: "a8a8a3")
    let tertiaryText = Color(hex: "9c9c97")
    let placeholderText = Color(hex: "a1a1aa")

    // Background colors - Rich, warm blacks with depth
    let primaryBackground = Color(hex: "0c0c0b")
    let secondaryBackground = Color(hex: "161614")
    let tertiaryBackground = Color(hex: "1e1e1c")

    // Sidebar colors - Deep and warm
    let sidebarBackground = Color(hex: "111110")
    let sidebarSelectedBackground = Color(hex: "222220")

    // Accent colors - Warm cream
    let accentColor = Color(hex: "f0f0eb")
    let accentColorLight = Color(hex: "a8a8a3")

    // Border colors - Warm and subtle
    let primaryBorder = Color(hex: "2a2a28")
    let secondaryBorder = Color(hex: "363633")
    let focusBorder = Color(hex: "8a8a85")

    // Status colors
    let successColor = Color(hex: "22c55e")
    let warningColor = Color(hex: "eab308")
    let errorColor = Color(hex: "ef4444")
    let infoColor = Color(hex: "a8a8a3")

    // Component specific
    let cardBackground = Color(hex: "161614")
    let cardBorder = Color(hex: "2a2a28")
    let buttonBackground = Color(hex: "f0f0eb")
    let buttonBorder = Color(hex: "f0f0eb")
    let inputBackground = Color(hex: "1a1a18")
    let inputBorder = Color(hex: "363633")
    let glassTintOverlay = Color(hex: "1a1a18").opacity(0.7)
    let codeBlockBackground = Color(hex: "1a1a18")

    let selectionColor = Color(hex: "f0f0eb").opacity(0.25)
    let cursorColor = Color(hex: "f0f0eb")

    // Glass specific
    let glassOpacityPrimary: Double = 0.20
    let glassOpacitySecondary: Double = 0.15
    let glassOpacityTertiary: Double = 0.08
    let glassBlurRadius: Double = 28
    let glassEdgeLight = Color.white.opacity(0.12)

    let cardShadowRadius: Double = 16
    let cardShadowRadiusHover: Double = 24
    let cardShadowY: Double = 4
    let cardShadowYHover: Double = 10

    let animationDurationQuick: Double = 0.2
    let animationDurationMedium: Double = 0.3
    let animationDurationSlow: Double = 0.4
    let animationSpringResponse: Double = 0.4
    let animationSpringDamping: Double = 0.8
    var animationSpring: Animation {
        .spring(response: animationSpringResponse, dampingFraction: animationSpringDamping)
    }

    let shadowColor = Color.black
    let shadowOpacity: Double = 0.4

    let isDark = true
}

// MARK: - Customizable Theme

struct CustomizableTheme: ThemeProtocol {
    let config: CustomTheme
    let fontScale: Double

    init(config: CustomTheme, fontScale: Double = ThemeManager.fontScale) {
        var config = config
        if config.followsSystemAccent,
           let accentHex = SystemAccentColor.currentAccentHex(isDark: config.isDark) {
            config.colors = config.colors.applyingAccent(accentHex, isDark: config.isDark)
        }
        self.config = config
        self.fontScale = fontScale
    }

    // Primary colors
    var primaryText: Color { Color(themeHex: config.colors.primaryText) }
    var secondaryText: Color { Color(themeHex: config.colors.secondaryText) }
    var tertiaryText: Color { Color(themeHex: config.colors.tertiaryText) }
    var placeholderText: Color {
        if let placeholder = config.colors.placeholderText {
            return Color(themeHex: placeholder)
        }
        return Color(themeHex: config.colors.tertiaryText)
    }

    // Background colors
    var primaryBackground: Color { Color(themeHex: config.colors.primaryBackground) }
    var secondaryBackground: Color { Color(themeHex: config.colors.secondaryBackground) }
    var tertiaryBackground: Color { Color(themeHex: config.colors.tertiaryBackground) }

    // Sidebar colors
    var sidebarBackground: Color { Color(themeHex: config.colors.sidebarBackground) }
    var sidebarSelectedBackground: Color { Color(themeHex: config.colors.sidebarSelectedBackground) }

    // Accent colors
    var accentColor: Color { Color(themeHex: config.colors.accentColor) }
    var accentColorLight: Color { Color(themeHex: config.colors.accentColorLight) }

    // Border colors
    var primaryBorder: Color { Color(themeHex: config.colors.primaryBorder) }
    var secondaryBorder: Color { Color(themeHex: config.colors.secondaryBorder) }
    var focusBorder: Color { Color(themeHex: config.colors.focusBorder) }

    // Status colors
    var successColor: Color { Color(themeHex: config.colors.successColor) }
    var warningColor: Color { Color(themeHex: config.colors.warningColor) }
    var errorColor: Color { Color(themeHex: config.colors.errorColor) }
    var infoColor: Color { Color(themeHex: config.colors.infoColor) }

    // Component specific
    var cardBackground: Color { Color(themeHex: config.colors.cardBackground) }
    var cardBorder: Color { Color(themeHex: config.colors.cardBorder) }
    var buttonBackground: Color { Color(themeHex: config.colors.buttonBackground) }
    var buttonBorder: Color { Color(themeHex: config.colors.buttonBorder) }
    var inputBackground: Color { Color(themeHex: config.colors.inputBackground) }
    var inputBorder: Color { Color(themeHex: config.colors.inputBorder) }
    var glassTintOverlay: Color { Color(themeHex: config.colors.glassTintOverlay) }
    var codeBlockBackground: Color { Color(themeHex: config.colors.codeBlockBackground) }

    var selectionColor: Color { Color(themeHex: config.colors.selectionColor) }
    var cursorColor: Color { Color(themeHex: config.colors.cursorColor) }

    var isDark: Bool { config.isDark }

    // Glass specific
    var glassOpacityPrimary: Double { config.glass.opacityPrimary }
    var glassOpacitySecondary: Double { config.glass.opacitySecondary }
    var glassOpacityTertiary: Double { config.glass.opacityTertiary }
    var glassBlurRadius: Double { config.glass.blurRadius }
    var glassEdgeLight: Color { Color(themeHex: config.glass.edgeLight) }
    var glassEnabled: Bool { config.glass.enabled }
    var glassSidebarEnabled: Bool { config.glass.sidebarEnabled }
    var glassInputEnabled: Bool { config.glass.inputEnabled }
    var glassMaterial: NSVisualEffectView.Material { config.glass.material.nsMaterial }
    var glassTintColor: Color? {
        guard let tint = config.glass.tintColor else { return nil }
        return Color(themeHex: tint)
    }
    var glassTintOpacity: Double { config.glass.tintOpacity ?? 0 }
    var windowBackingOpacity: Double { config.glass.windowBackingOpacity }

    // Card shadows
    var cardShadowRadius: Double { config.shadows.cardShadowRadius }
    var cardShadowRadiusHover: Double { config.shadows.cardShadowRadiusHover }
    var cardShadowY: Double { config.shadows.cardShadowY }
    var cardShadowYHover: Double { config.shadows.cardShadowYHover }

    // Animation timing
    var animationDurationQuick: Double { config.animationConfig.durationQuick }
    var animationDurationMedium: Double { config.animationConfig.durationMedium }
    var animationDurationSlow: Double { config.animationConfig.durationSlow }
    var animationSpringResponse: Double { config.animationConfig.springResponse }
    var animationSpringDamping: Double { config.animationConfig.springDamping }
    var animationSpring: Animation { config.animationConfig.spring }

    // Shadows
    var shadowColor: Color { Color(themeHex: config.colors.shadowColor) }
    var shadowOpacity: Double { config.shadows.shadowOpacity }

    // Background customization
    var backgroundImage: NSImage? { config.background.decodedImage() }
    var backgroundImageOpacity: Double { config.background.imageOpacity ?? 1.0 }
    var backgroundOverlayColor: Color? {
        guard let overlay = config.background.overlayColor else { return nil }
        return Color(themeHex: overlay)
    }
    var backgroundOverlayOpacity: Double { config.background.overlayOpacity ?? 0 }

    // Typography
    var primaryFontName: String { config.typography.primaryFont }
    var monoFontName: String { config.typography.monoFont }
    var titleSize: Double { config.typography.titleSize * fontScale }
    var headingSize: Double { config.typography.headingSize * fontScale }
    var bodySize: Double { config.typography.bodySize * fontScale }
    var captionSize: Double { config.typography.captionSize * fontScale }
    var codeSize: Double { config.typography.codeSize * fontScale }

    var codeHighlightTheme: String? { config.codeHighlightTheme }
    var customThemeConfig: CustomTheme? { config }

    // Message bubble customization
    var bubbleCornerRadius: Double { config.messages.bubbleCornerRadius }
    var userBubbleOpacity: Double { config.messages.userBubbleOpacity }
    var assistantBubbleOpacity: Double { config.messages.assistantBubbleOpacity }
    var userBubbleColor: Color? {
        guard let hex = config.messages.userBubbleColor else { return nil }
        return Color(themeHex: hex)
    }
    var assistantBubbleColor: Color? {
        guard let hex = config.messages.assistantBubbleColor else { return nil }
        return Color(themeHex: hex)
    }
    var messageBorderWidth: Double { config.messages.borderWidth }
    var showEdgeLight: Bool { config.messages.showEdgeLight }
    var showInlineAvatar: Bool { config.messages.showInlineAvatar }
    var inlineAvatarSize: Double { config.messages.inlineAvatarSize }
    var showAgentName: Bool { config.messages.showAgentName }
    var agentNameSize: Double { config.messages.agentNameSize * fontScale }

    // Border customization
    var defaultBorderWidth: Double { config.borders.defaultWidth }
    var cardCornerRadius: Double { config.borders.cardCornerRadius }
    var inputCornerRadius: Double { config.borders.inputCornerRadius }
    var borderOpacity: Double { config.borders.borderOpacity }
}

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
            UserDefaults.standard.set(clamped, forKey: "ApexKeyFontScale")
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
        let savedScale = UserDefaults.standard.double(forKey: "ApexKeyFontScale")
        Self.fontScale = savedScale > 0 ? savedScale : 1.0

        let savedThemeId = UserDefaults.standard.string(forKey: "ApexKeyActiveThemeId")
        let savedMode = UserDefaults.standard.string(forKey: "ApexKeyAppearanceMode") ?? "system"
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
            UserDefaults.standard.set(mode.rawValue, forKey: "ApexKeyAppearanceMode")
        }
        if clearActiveTheme {
            activeCustomTheme = nil
            UserDefaults.standard.removeObject(forKey: "ApexKeyActiveThemeId")
        }

        guard activeCustomTheme == nil else { return }

        applyResolvedTheme(for: mode, animated: true)
        NotificationCenter.default.post(name: .globalThemeChanged, object: nil)
    }

    public func applyCustomTheme(_ theme: CustomTheme, persist: Bool = true, animated: Bool = true) {
        activeCustomTheme = theme
        if persist {
            UserDefaults.standard.set(theme.metadata.id.uuidString, forKey: "ApexKeyActiveThemeId")
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
            UserDefaults.standard.removeObject(forKey: "ApexKeyActiveThemeId")
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

// MARK: - Appearance Mode

public enum AppearanceMode: String, Codable, CaseIterable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"
}// MARK: - Theme Environment Key

struct ThemeEnvironmentKey: EnvironmentKey {
    static var defaultValue: ThemeProtocol { LightTheme() }
}

extension EnvironmentValues {
    var theme: ThemeProtocol {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - View Extensions

extension View {
    func themedBackground(_ style: ThemedBackgroundStyle = .primary) -> some View {
        self.modifier(ThemedBackgroundModifier(style: style))
    }

    func themedCard() -> some View {
        self.modifier(ThemedCardModifier())
    }
}

enum ThemedBackgroundStyle {
    case primary
    case secondary
    case tertiary
}

struct ThemedBackgroundModifier: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared
    let style: ThemedBackgroundStyle

    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .environment(\.theme, themeManager.currentTheme)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return themeManager.currentTheme.primaryBackground
        case .secondary: return themeManager.currentTheme.secondaryBackground
        case .tertiary: return themeManager.currentTheme.tertiaryBackground
        }
    }
}

struct ThemedCardModifier: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        let theme = themeManager.currentTheme
        content
            .background(theme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                    .stroke(theme.cardBorder.opacity(theme.borderOpacity), lineWidth: theme.defaultBorderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius))
            .shadow(
                color: theme.shadowColor.opacity(theme.shadowOpacity),
                radius: 8,
                x: 0,
                y: 2
            )
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64, r: UInt64, g: UInt64, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }

}