import SwiftUI

/// 테마 설정 섹션 — 외형 모드, 내장 테마 프리셋, 폰트 스케일
struct ThemeSettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSubsection(label: "appearance.mode".localized) {
                Picker("appearance.picker".localized, selection: appearanceBinding) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            SettingsSubsection(label: "appearance.preset".localized) {
                if themeManager.installedThemes.isEmpty {
                    Text("appearance.loading".localized)
                        .font(.caption)
                        .foregroundColor(theme.tertiaryText)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(themeManager.installedThemes) { preset in
                            themeChip(preset)
                        }
                    }
                }
            }

            SettingsSubsection(label: "appearance.text_size".localized) {
                HStack(spacing: 12) {
                    Button {
                        themeManager.zoomFontOut()
                    } label: {
                        Image(systemName: "textformat.size.smaller")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .disabled(!themeManager.canZoomFontOut)

                    Button {
                        themeManager.resetFontScale()
                    } label: {
                        Text("\(Int(ThemeManager.fontScale * 100))%")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(theme.primaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(theme.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(theme.inputBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("appearance.reset_help".localized)
                    .disabled(themeManager.isDefaultFontScale)

                    Button {
                        themeManager.zoomFontIn()
                    } label: {
                        Image(systemName: "textformat.size.larger")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .disabled(!themeManager.canZoomFontIn)
                }
            }
        }
        .onAppear {
            themeManager.loadInstalledThemes()
        }
    }

    private var appearanceBinding: Binding<AppearanceMode> {
        Binding(
            get: { themeManager.appearanceMode },
            set: { themeManager.setAppearanceMode($0) }
        )
    }

    private func themeChip(_ preset: CustomTheme) -> some View {
        let isActive = themeManager.activeCustomTheme?.metadata.id == preset.metadata.id
        return Button {
            if isActive {
                themeManager.clearCustomTheme()
            } else {
                themeManager.applyCustomTheme(preset)
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: preset.colors.accentColor))
                        .frame(width: 14, height: 14)
                    Circle()
                        .fill(Color(hex: preset.colors.primaryBackground))
                        .frame(width: 14, height: 14)
                    Circle()
                        .fill(Color(hex: preset.colors.secondaryBackground))
                        .frame(width: 14, height: 14)
                    Spacer()
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(theme.accentColor)
                    }
                }
                Text(preset.metadata.name)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(isActive ? theme.primaryText : theme.secondaryText)
                    .lineLimit(1)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? theme.sidebarSelectedBackground : theme.inputBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? theme.accentColor.opacity(0.4) : theme.inputBorder.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

extension AppearanceMode {
    var displayName: String {
        switch self {
        case .system: return "appearance.system".localized
        case .light: return "appearance.light".localized
        case .dark: return "appearance.dark".localized
        }
    }
}

extension CustomTheme: Identifiable {
    public var id: UUID { metadata.id }
}
