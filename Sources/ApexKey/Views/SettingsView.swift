import SwiftUI
import ServiceManagement

/// 설정 창 (일반 설정 전용) — 메뉴바/Dock 표시 토글 포함
struct SettingsView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var showGuardAlert = false
    @State private var recordingPanelHotkey = false
    @State private var recordingHUDHotkey = false
    @State private var showRestartBanner = false

    var body: some View {
        Form {
            Section("settings.display".localized) {
                Toggle("settings.show_in_menubar".localized, isOn: menuBarBinding)
                Text("settings.show_in_menubar.description".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                Toggle("settings.show_in_dock".localized, isOn: dockBinding)
                Text("settings.show_in_dock.description".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }

            Section {
                Toggle("settings.launch_at_login".localized, isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        applyLaunchAtLogin(newValue)
                    }
                Toggle("settings.show_hidden_apps".localized, isOn: $store.showHiddenApps)
                Toggle("settings.show_system_apps".localized, isOn: $store.showSystemApps)
            }

            Section("settings.panel_hotkey".localized) {
                HStack {
                    Text("settings.panel_hotkey.current".localized)
                    Spacer()
                    Text(store.toggleHotkey.displayString)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.tertiaryBackground.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text("settings.panel_hotkey.description".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                Button("settings.panel_hotkey.change".localized) {
                    recordingPanelHotkey = true
                }
                Button("settings.panel_hotkey.reset".localized) {
                    store.setPanelToggleHotkey(ConfigStore.defaultToggleHotkey)
                }
            }

            Section("settings.menu_hud".localized) {
                HStack {
                    Text("settings.menu_hud.current".localized)
                    Spacer()
                    Text(store.menuHUDHotkey.displayString)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.tertiaryBackground.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text("settings.menu_hud.description".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                Picker("settings.menu_hud.style".localized, selection: Binding(
                    get: { store.menuHUDStyle },
                    set: { store.setMenuHUDStyle($0) }
                )) {
                    ForEach(ConfigStore.MenuHUDStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                Button("settings.menu_hud.change".localized) {
                    recordingHUDHotkey = true
                }
                Button("settings.menu_hud.reset".localized) {
                    store.setMenuHUDHotkey(ConfigStore.defaultMenuHUDHotkey)
                }
            }

            Section("settings.permissions".localized) {
                HStack {
                    Text("settings.permissions.accessibility".localized)
                    Spacer()
                    Button(PermissionHelper.isAccessibilityTrusted ? "settings.permissions.accessibility.granted".localized : "settings.permissions.accessibility.request".localized) {
                        PermissionHelper.requestAccessibility()
                    }
                    .disabled(PermissionHelper.isAccessibilityTrusted)
                }
                Text("settings.permissions.accessibility.description".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }

            Section("settings.language".localized) {
                Picker("settings.language".localized, selection: Binding(
                    get: { store.appLanguage },
                    set: { newValue in
                        store.appLanguage = newValue
                        showRestartBanner = true
                    }
                )) {
                    ForEach(LanguageManager.shared.supportedLanguages, id: \.code) { lang in
                        Text(lang.displayName).tag(lang.code)
                    }
                }
                .pickerStyle(.menu)
                
                if showRestartBanner {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.orange)
                        Text("settings.language.restart_required".localized)
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("settings.theme".localized) {
                ThemeSettingsView()
            }
        }
        .formStyle(.grouped)
        .background(theme.primaryBackground)
        .frame(minWidth: 560, minHeight: 400)
        .sheet(isPresented: $recordingPanelHotkey) {
            HotKeyRecorderView(
                title: "settings.panel_hotkey".localized,
                subtitle: "ui.appdetail.run_globally".localized,
                excludedCombo: store.toggleHotkey,
                onTest: { _ in
                    NotificationCenter.default.post(name: .togglePanel, object: nil)
                    return true
                }
            ) { combo in
                store.setPanelToggleHotkey(combo)
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $recordingHUDHotkey) {
            HotKeyRecorderView(
                title: "settings.menu_hud".localized,
                subtitle: "ui.appdetail.run_globally".localized,
                excludedCombo: store.menuHUDHotkey,
                onTest: { _ in
                    NotificationCenter.default.post(name: .toggleMenuHUD, object: nil)
                    return true
                }
            ) { combo in
                store.setMenuHUDHotkey(combo)
            }
            .environmentObject(store)
        }
        .alert("alert.menubar_cannot_disable.title".localized, isPresented: $showGuardAlert) {
            Button("ui.settings.ok".localized, role: .cancel) {}
        } message: {
            Text("alert.menubar_cannot_disable.message".localized)
        }
    }

    /// 메뉴바 토글 — Dock도 꺼져 있으면 거부 + 안내
    private var menuBarBinding: Binding<Bool> {
        Binding(
            get: { store.showInMenuBar },
            set: { newValue in
                if !store.setMenuBarVisible(newValue) {
                    showGuardAlert = true
                }
            }
        )
    }

    private var dockBinding: Binding<Bool> {
        Binding(
            get: { store.showInDock },
            set: { store.setDockVisible($0) }
        )
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            Logger.error("E-MAC-LOGIN-7001", "로그인 시작 설정 실패: \(error.localizedDescription)")
        }
    }
}