import AppKit
import SwiftUI

/// 터미널에서 열기 단계 설정 (T-195)
///
/// 왜 전용 UI가 필요한가: `implementation == .implemented`인 액션은 카탈로그에서 **선택된다.**
/// 전용 UI 없이 기본 화면으로 두면 "터미널에서 열기"를 골라도 앱·방식을 정할 곳이 없다 —
/// 선택은 되지만 쓸 수 없는 상태(T-159가 고친 그 상태)를 다시 만든다.
struct TerminalOpenSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep

    private var config: TerminalOpenConfig { TerminalOpenConfig.decode(from: step.actionParameters) }

    private func updateConfig(_ mutate: (inout TerminalOpenConfig) -> Void) {
        var next = config
        mutate(&next)
        step.actionParameters = next.encode()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(step.type.displayName)
                .font(.headline)

            Text("ui.title".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("ui.title".localized, text: $step.title)
                .textFieldStyle(.roundedBorder)

            Text("terminal.open.path".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            HStack {
                TextField("terminal.open.path_hint".localized, text: $step.target)
                    .textFieldStyle(.roundedBorder)
                Button("ui.browse".localized) { chooseFolder() }
            }

            Picker("terminal.open.app".localized, selection: appBinding) {
                ForEach(TerminalApp.allCases) { app in
                    Text(app.displayName).tag(app.bundleID)
                }
                Text("terminal.open.app.auto".localized).tag("")
            }
            .pickerStyle(.menu)

            Picker("terminal.open.mode".localized, selection: modeBinding) {
                Text("terminal.open.mode.window".localized).tag(false)
                Text("terminal.open.mode.tab".localized).tag(true)
            }
            .pickerStyle(.radioGroup)

            Text(step.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                 ? "terminal.open.source_finder".localized
                 : "terminal.open.source_path".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)

            if config.openInNewTab {
                Text("terminal.open.tab_notice".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }
        }
        .sectionCard()
    }

    private var appBinding: Binding<String> {
        Binding(
            get: { config.appBundleID ?? "" },
            set: { raw in
                let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                updateConfig { $0.appBundleID = value.isEmpty ? nil : value }
            }
        )
    }

    private var modeBinding: Binding<Bool> {
        Binding(
            get: { config.openInNewTab },
            set: { newValue in updateConfig { $0.openInNewTab = newValue } }
        )
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            step.target = url.path
            if step.title.isEmpty { step.title = url.lastPathComponent }
        }
    }
}
