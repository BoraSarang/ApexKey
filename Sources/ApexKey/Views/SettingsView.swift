import SwiftUI
import ServiceManagement

/// 설정 창 (일반 설정 전용) — 메뉴바/Dock 표시 토글 포함
struct SettingsView: View {
    @EnvironmentObject var store: ConfigStore
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var showGuardAlert = false
    @State private var recordingPanelHotkey = false
    @State private var recordingHUDHotkey = false

    var body: some View {
        Form {
            Section("표시") {
                Toggle("메뉴바에 표시", isOn: menuBarBinding)
                Text("끄면 메뉴바 아이콘이 사라집니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Toggle("Dock에 표시", isOn: dockBinding)
                Text("켜면 Dock 아이콘으로도 접근할 수 있습니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Toggle("로그인 시 시작", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        applyLaunchAtLogin(newValue)
                    }
                Toggle("숨김 앱 표시", isOn: $store.showHiddenApps)
            }

            Section("패널 단축키") {
                HStack {
                    Text("현재")
                    Spacer()
                    Text(store.toggleHotkey.displayString)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text("메인 패널을 열고 닫는 전역 단축키 (⇧⌥A 기본).")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("단축키 변경") {
                    recordingPanelHotkey = true
                }
                Button("기본값 복원") {
                    store.setPanelToggleHotkey(ConfigStore.defaultToggleHotkey)
                }
            }

            Section("메뉴 단축키 HUD") {
                HStack {
                    Text("현재")
                    Spacer()
                    Text(store.menuHUDHotkey.displayString)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text("현재 전면 앱의 모든 메뉴 단축키를 표시 (⇧⌥S 기본).")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("표시 방식", selection: Binding(
                    get: { store.menuHUDStyle },
                    set: { store.setMenuHUDStyle($0) }
                )) {
                    ForEach(ConfigStore.MenuHUDStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                Button("단축키 변경") {
                    recordingHUDHotkey = true
                }
                Button("기본값 복원") {
                    store.setMenuHUDHotkey(ConfigStore.defaultMenuHUDHotkey)
                }
            }

            Section("권한") {
                HStack {
                    Text("손쉬운 사용(Accessibility)")
                    Spacer()
                    Button(PermissionHelper.isAccessibilityTrusted ? "✅ 허용됨" : "권한 요청") {
                        PermissionHelper.requestAccessibility()
                    }
                    .disabled(PermissionHelper.isAccessibilityTrusted)
                }
                Text("메뉴 단축키 열거·실행과 타 앱 제어에 필요합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 560, minHeight: 400)
        .sheet(isPresented: $recordingPanelHotkey) {
            HotKeyRecorderView(
                title: "패널 토글 단축키",
                subtitle: "전역에서 실행",
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
                title: "메뉴 단축키 HUD 단축키",
                subtitle: "전역에서 실행",
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
        .alert("메뉴바를 끌 수 없습니다", isPresented: $showGuardAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("Dock에 표시도 꺼져 있으면 앱에 접근할 수 없습니다. Dock에 표시를 먼저 켜주세요.")
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
