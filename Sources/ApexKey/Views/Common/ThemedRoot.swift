import SwiftUI

/// Root-level theme container for a window. Observes the shared `ThemeManager`,
/// injects `\.theme` into the environment, and sets the preferred color scheme
/// so AppKit/SwiftUI system colors follow the active theme.
struct ThemedRoot<Content: View>: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .environment(\.theme, themeManager.currentTheme)
            .preferredColorScheme(themeManager.currentTheme.isDark ? .dark : .light)
    }
}
