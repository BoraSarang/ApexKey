import SwiftUI

/// T-222 App Intents·자동화 카탈로그 설정.
///
/// `appIntent`는 Shortcuts 앱에서 App Intent를 감싼 단축어 이름을 받는다.
/// 공개 런타임 API로 App Intent를 직접 호출할 수 없기 때문이다.
struct AppIntentAutomationSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep

    private var config: AppIntentAutomationConfig {
        AppIntentAutomationConfig.decode(from: step.actionParameters)
    }

    private func updateConfig(_ mutate: (inout AppIntentAutomationConfig) -> Void) {
        var next = config
        mutate(&next)
        step.actionParameters = next.encode()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(step.type.displayName)
                .font(.headline)

            controls

            hint
        }
        .sectionCard()
    }

    @ViewBuilder
    private var controls: some View {
        switch step.type {
        case .findApp:
            textField("intent.query".localized, value: config.query ?? "") { value in
                updateConfig { $0.query = value }
            }
            Toggle("intent.include_system_apps".localized, isOn: Binding(
                get: { config.resolvedIncludeSystemApps },
                set: { value in updateConfig { $0.includeSystemApps = value } }
            ))
            .toggleStyle(.checkbox)

        case .appIntent:
            textField("intent.shortcut_name".localized, value: config.shortcutName ?? "") { value in
                updateConfig { $0.shortcutName = value }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("intent.input".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                GrowingTextEditor(text: Binding(
                    get: { config.input ?? "" },
                    set: { value in updateConfig { $0.input = value } }
                ))
                .frame(minHeight: 64)
            }

        case .appAction:
            textField("intent.url".localized, value: config.url ?? "") { value in
                updateConfig { $0.url = value }
            }

        case .automation, .findAutomation:
            textField("intent.query".localized, value: config.query ?? "") { value in
                updateConfig { $0.query = value }
            }
            Toggle("intent.include_unsupported".localized, isOn: Binding(
                get: { config.resolvedIncludeUnsupported },
                set: { value in updateConfig { $0.includeUnsupported = value } }
            ))
            .toggleStyle(.checkbox)

        case .automationRun:
            textField("intent.shortcut_name".localized, value: config.shortcutName ?? "") { value in
                updateConfig { $0.shortcutName = value }
            }

        case .trigger:
            textField("intent.shortcut_name".localized, value: config.shortcutName ?? "") { value in
                updateConfig { $0.shortcutName = value }
            }
            textField("intent.trigger_name".localized, value: config.triggerName ?? "") { value in
                updateConfig { $0.triggerName = value }
            }

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var hint: some View {
        switch step.type {
        case .findApp:
            Text("intent.find_app_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        case .appIntent:
            Text("intent.app_intent_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        case .appAction:
            Text("intent.app_action_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        case .automation, .findAutomation:
            Text("intent.automation_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        case .automationRun:
            Text("intent.run_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        case .trigger:
            Text("intent.trigger_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        default:
            EmptyView()
        }
    }

    private func textField(
        _ title: String,
        value: String,
        onChange: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("intent.value_hint".localized, text: Binding(get: { value }, set: onChange))
                .textFieldStyle(.roundedBorder)
        }
    }
}
