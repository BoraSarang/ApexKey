import SwiftUI

/// T-219 시스템 제어 — Wi-Fi·집중 모드 단계 설정.
struct SystemControlSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep

    private var config: SystemControlConfig {
        SystemControlConfig.decode(from: step.actionParameters)
    }

    private func updateConfig(_ mutate: (inout SystemControlConfig) -> Void) {
        var next = config
        mutate(&next)
        step.actionParameters = next.encode()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(step.type.displayName)
                .font(.headline)

            switch step.type {
            case .network:
                Picker("wifi.action".localized, selection: Binding(
                    get: { config.resolvedWiFiAction },
                    set: { value in updateConfig { $0.wifiAction = value } }
                )) {
                    ForEach(SystemControlConfig.WiFiAction.allCases, id: \.self) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .pickerStyle(.menu)

                Text("wifi.hint".localized)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)

            case .focusMode:
                TextField("focus.shortcut_hint".localized, text: Binding(
                    get: { config.shortcutName ?? "" },
                    set: { value in updateConfig { $0.shortcutName = value } }
                ))
                .textFieldStyle(.roundedBorder)

                Text("focus.hint".localized)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)

            default:
                EmptyView()
            }
        }
        .sectionCard()
    }
}
