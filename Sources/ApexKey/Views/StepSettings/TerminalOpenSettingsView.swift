import AppKit
import SwiftUI

/// 터미널에서 열기 단계 설정 (T-195, R-20261121-01).
///
/// 왜 전용 UI가 필요한가: `implementation == .implemented`인 액션은 카탈로그에서 **선택된다.**
/// 전용 UI 없이 기본 화면으로 두면 "터미널에서 열기"를 골라도 앱·방식을 정할 곳이 없다 —
/// 선택은 되지만 쓸 수 없는 상태(T-159가 고친 그 상태)를 다시 만든다.
///
/// 앱 목록은 known(iTerm2·터미널) + **직접 고른 앱**이다. 직접 고른 앱은 새 창만 지원한다
/// (새 탭은 앱별 AppleScript가 필요).
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
                Text("terminal.open.app.auto".localized).tag("")
                ForEach(TerminalApp.allCases) { app in
                    Text(app.displayName).tag(app.bundleID)
                }
                if let customAppTag {
                    Text(customAppName).tag(customAppTag)
                }
            }
            .pickerStyle(.menu)

            Button("terminal.open.app.other".localized) { chooseApp() }
                .buttonStyle(.bordered)
                .controlSize(.small)

            if isCustomApp {
                Text("terminal.open.custom_window_only".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            } else {
                Picker("terminal.open.mode".localized, selection: modeBinding) {
                    Text("terminal.open.mode.window".localized).tag(false)
                    Text("terminal.open.mode.tab".localized).tag(true)
                }
                .pickerStyle(.radioGroup)

                if config.openInNewTab {
                    Text("terminal.open.tab_notice".localized)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
            }

            if step.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("terminal.open.source_finder".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                // 파인더 경로 읽기는 AppleScript(자동화)라 첫 사용에 승인이 필요하다 — 미리 알린다
                Text("terminal.open.finder_permission".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            } else {
                Text("terminal.open.source_path".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }
        }
        .sectionCard()
        .onAppear {
            // 직접 고른 앱은 새 탭을 지원하지 않는다 — 예전 설정이 남아 있으면 새 창으로 정리
            if isCustomApp && config.openInNewTab {
                updateConfig { $0.openInNewTab = false }
            }
        }
    }

    // MARK: - 앱 선택 상태

    private var trimmedBundleID: String {
        config.appBundleID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// known enum에 없는 앱(번들ID 또는 경로만 저장)인가
    private var isCustomApp: Bool {
        if !trimmedBundleID.isEmpty {
            return TerminalApp(rawValue: trimmedBundleID) == nil
        }
        return !(config.appPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    /// Picker에서 직접 고른 앱을 가리키는 태그 (번들ID 우선, 없으면 경로)
    private var customAppTag: String? {
        guard isCustomApp else { return nil }
        if !trimmedBundleID.isEmpty { return trimmedBundleID }
        return config.appPath
    }

    private var customAppName: String {
        if let path = config.appPath, !path.isEmpty,
           let bundle = Bundle(url: URL(fileURLWithPath: path)) {
            return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        }
        return trimmedBundleID
    }

    private var appBinding: Binding<String> {
        Binding(
            get: { customAppTag ?? trimmedBundleID },
            set: { raw in
                let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if value.isEmpty {
                    updateConfig {
                        $0.appBundleID = nil
                        $0.appPath = nil
                    }
                } else if TerminalApp(rawValue: value) != nil {
                    updateConfig {
                        $0.appBundleID = value
                        $0.appPath = nil
                    }
                }
                // 직접 고른 앱 태그는 이미 저장된 값이므로 변경 없음
            }
        )
    }

    private var modeBinding: Binding<Bool> {
        Binding(
            get: { config.openInNewTab },
            set: { newValue in updateConfig { $0.openInNewTab = newValue } }
        )
    }

    // MARK: - 피커

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

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.applicationBundle]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let bundleID = Bundle(url: url)?.bundleIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updateConfig {
            $0.appBundleID = bundleID.isEmpty ? nil : bundleID
            $0.appPath = TerminalApp(rawValue: bundleID) == nil ? url.path : nil
            $0.openInNewTab = false
        }
    }
}
