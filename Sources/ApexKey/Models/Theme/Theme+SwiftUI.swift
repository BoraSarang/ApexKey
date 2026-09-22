import AppKit
import SwiftUI

// MARK: - Theme Environment Key
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
