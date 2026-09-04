import SwiftUI

// MARK: - Settings Section

/// Card-style settings section with an uppercased title + icon header.
struct SettingsSection<Content: View>: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.accentColor)

                Text(title)
                    .textCase(.uppercase)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .tracking(0.5)
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: themeManager.currentTheme.cardCornerRadius)
                .fill(themeManager.currentTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: themeManager.currentTheme.cardCornerRadius)
                        .stroke(themeManager.currentTheme.cardBorder.opacity(themeManager.currentTheme.borderOpacity), lineWidth: themeManager.currentTheme.defaultBorderWidth)
                )
        )
    }
}

// MARK: - Settings Field

struct SettingsField<Content: View>: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    let label: String
    var hint: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(themeManager.currentTheme.secondaryText)

            content()

            if let hint = hint {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.currentTheme.tertiaryText)
            }
        }
    }
}

// MARK: - Settings Subsection

struct SettingsSubsection<Content: View>: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(themeManager.currentTheme.accentColor)
                    .frame(width: 3, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))

                Text(label)
                    .textCase(.uppercase)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.tertiaryText)
                    .tracking(0.5)
            }

            content()
                .padding(.leading, 9)
        }
    }
}

// MARK: - Styled Settings Text Field

struct StyledSettingsTextField: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    let label: String
    @Binding var text: String
    let placeholder: String
    let help: String

    @State private var isFocused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeManager.currentTheme.primaryText)

            HStack(spacing: 10) {
                ZStack(alignment: .leading) {
                    if text.isEmpty && !placeholder.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(themeManager.currentTheme.placeholderText)
                            .allowsHitTesting(false)
                    }

                    TextField(
                        "",
                        text: $text,
                        onEditingChanged: { editing in
                            withAnimation(.easeOut(duration: 0.15)) {
                                isFocused = editing
                            }
                        }
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(themeManager.currentTheme.primaryText)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: themeManager.currentTheme.inputCornerRadius)
                    .fill(themeManager.currentTheme.inputBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: themeManager.currentTheme.inputCornerRadius)
                            .stroke(
                                isFocused
                                    ? themeManager.currentTheme.accentColor.opacity(0.5)
                                    : themeManager.currentTheme.inputBorder,
                                lineWidth: isFocused ? 1.5 : 1
                            )
                    )
            )

            if !help.isEmpty {
                Text(help)
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.currentTheme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Settings Toggle

struct SettingsToggle: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(themeManager.currentTheme.primaryText)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(themeManager.currentTheme.tertiaryText)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: themeManager.currentTheme.accentColor))
                .labelsHidden()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: themeManager.currentTheme.inputCornerRadius)
                .fill(themeManager.currentTheme.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: themeManager.currentTheme.inputCornerRadius)
                        .stroke(themeManager.currentTheme.inputBorder.opacity(themeManager.currentTheme.borderOpacity), lineWidth: 1)
                )
        )
    }
}

// MARK: - Settings Divider

struct SettingsDivider: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        Rectangle()
            .fill(themeManager.currentTheme.cardBorder)
            .frame(height: 1)
    }
}

// MARK: - Settings Button Style

struct SettingsButtonStyle: ButtonStyle {
    @ObservedObject private var themeManager = ThemeManager.shared
    let isPrimary: Bool
    let isDestructive: Bool

    init(isPrimary: Bool = false, isDestructive: Bool = false) {
        self.isPrimary = isPrimary
        self.isDestructive = isDestructive
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(
                isDestructive
                    ? themeManager.currentTheme.errorColor
                    : (isPrimary ? .white : themeManager.currentTheme.primaryText)
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: themeManager.currentTheme.inputCornerRadius)
                    .fill(
                        isPrimary ? themeManager.currentTheme.accentColor : themeManager.currentTheme.tertiaryBackground
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: themeManager.currentTheme.inputCornerRadius)
                            .stroke(isPrimary ? Color.clear : themeManager.currentTheme.inputBorder, lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}
