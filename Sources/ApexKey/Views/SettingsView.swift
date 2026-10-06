import SwiftUI
import ServiceManagement

/// 설정 창 — 기능별 탭 (사이드바). 각 탭 상단에는 도움말 카드(뭐고·언제·이렇게).
/// 단축키 기록 시트는 6개 → 1개로 통합 (선택 슬롯 패턴).
/// 행 규칙: 라벨 왼쪽·컨트롤 오른쪽, 설명은 들여쓰기 캡션 (위계 고정).
struct SettingsView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var showGuardAlert = false
    @State private var showRestartBanner = false
    @State private var showUpdateSheet = false
    @State private var selectedTab: SettingsTab = .general
    @State private var recordingSlot: HotkeySlot?

    /// 단축키 슬롯 1건 — 6개 예약 핫키가 같은 저장/테스트 경로를 공유한다
    struct HotkeySlot: Identifiable {
        let id: SettingsTab
        let title: String
        let current: HotKeyCombo
        let excluded: HotKeyCombo
        let save: (HotKeyCombo) -> String?
        let reset: () -> Void
        let test: () -> Void
    }

    private func slot(for tab: SettingsTab) -> HotkeySlot? {
        switch tab {
        case .panel:
            return HotkeySlot(id: tab, title: "settings.panel_hotkey".localized,
                              current: store.toggleHotkey, excluded: store.toggleHotkey,
                              save: { store.setPanelToggleHotkey($0).errorMessage },
                              reset: { store.setPanelToggleHotkey(ConfigStore.defaultToggleHotkey) },
                              test: { NotificationCenter.default.post(name: .togglePanel, object: nil) })
        case .palette:
            return HotkeySlot(id: tab, title: "settings.palette".localized,
                              current: store.paletteHotkey, excluded: store.paletteHotkey,
                              save: { store.setPaletteHotkey($0).errorMessage },
                              reset: { store.setPaletteHotkey(ConfigStore.defaultPaletteHotkey) },
                              test: { store.showPalette.toggle() })
        case .clipboard:
            return HotkeySlot(id: tab, title: "settings.clipboard".localized,
                              current: store.clipboardHotkey, excluded: store.clipboardHotkey,
                              save: { store.setClipboardHotkey($0).errorMessage },
                              reset: { store.setClipboardHotkey(ConfigStore.defaultClipboardHotkey) },
                              test: { store.paletteMode = .clipboard; store.showPalette.toggle() })
        case .send:
            return HotkeySlot(id: tab, title: "settings.send".localized,
                              current: store.sendHotkey, excluded: store.sendHotkey,
                              save: { store.setSendHotkey($0).errorMessage },
                              reset: { store.setSendHotkey(ConfigStore.defaultSendHotkey) },
                              test: { store.fireInstantSend() })
        case .hud:
            return HotkeySlot(id: tab, title: "settings.menu_hud".localized,
                              current: store.menuHUDHotkey, excluded: store.menuHUDHotkey,
                              save: { store.setMenuHUDHotkey($0).errorMessage },
                              reset: { store.setMenuHUDHotkey(ConfigStore.defaultMenuHUDHotkey) },
                              test: { NotificationCenter.default.post(name: .toggleMenuHUD, object: nil) })
        case .icons:
            return HotkeySlot(id: tab, title: "menubar.icons.title".localized,
                              current: store.menuBarIconsHotkey, excluded: store.menuBarIconsHotkey,
                              save: { store.setMenuBarIconsHotkey($0).errorMessage },
                              reset: { store.setMenuBarIconsHotkey(ConfigStore.defaultMenuBarIconsHotkey) },
                              test: { NotificationCenter.default.post(name: .toggleMenuBarIcons, object: nil) })
        case .general, .theme:
            return nil
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.primaryBackground)
        .frame(minWidth: 700, minHeight: 460)
        .sheet(item: $recordingSlot) { slot in
            HotKeyRecorderView(
                title: slot.title,
                subtitle: "ui.appdetail.run_globally".localized,
                excludedCombo: slot.excluded,
                onTest: { _ in slot.test(); return true }
            ) { combo in
                slot.save(combo)
            }
            .environmentObject(store)
        }
        .alert("alert.menubar_cannot_disable.title".localized, isPresented: $showGuardAlert) {
            Button("ui.settings.ok".localized, role: .cancel) {}
        } message: {
            Text("alert.menubar_cannot_disable.message".localized)
        }
        .sheet(isPresented: $showUpdateSheet) {
            if let release = store.availableUpdate {
                UpdateAvailableSheet(
                    release: release,
                    currentVersion: ReleaseChecker.currentVersion
                )
            }
        }
    }

    // MARK: - 사이드바

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 13))
                            .frame(width: 20)
                        Text(tab.titleKey.localized)
                            .font(.body)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(selectedTab == tab ? theme.accentColor.opacity(0.14) : Color.clear)
                    .foregroundColor(selectedTab == tab ? theme.accentColor : theme.primaryText)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(10)
        .frame(width: 190)
    }

    // MARK: - 행 시스템 (라벨 좌·컨트롤 우·설명 들여쓰기)

    /// 그룹 박스 — macOS 설정 앱식 카드. 제목과 내용의 왼쪽선을 일치시킨다.
    /// (GroupBox 기본 라벨은 내용보다 안쪽으로 들어가 위계가 뒤집히므로 직접 그린다.)
    private func groupBox<Content: View>(_ titleKey: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titleKey.localized)
                .font(.headline)
                .padding(.leading, 12)
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.tertiaryBackground.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    /// 설명 캡션 — 라벨 아래 들여쓰기로 종속 표시
    private func caption(_ key: String) -> some View {
        Text(key.localized)
            .font(.caption)
            .foregroundColor(theme.secondaryText)
            .padding(.leading, 2)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 토글 행 — 라벨은 왼쪽, 스위치는 오른쪽 끝
    private func toggleRow(_ key: String, isOn: Binding<Bool>, description: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(key.localized)
                    .font(.body)
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            if let description {
                caption(description)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - 탭 내용

    @ViewBuilder
    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                FeatureHelpCard(prefix: selectedTab.helpPrefix)
                switch selectedTab {
                case .general: generalSections
                case .panel, .palette, .clipboard, .send: hotkeyOnlySection
                case .hud: hudSections
                case .icons: iconsSections
                case .theme: themeSections
                }
            }
            .padding(18)
        }
    }

    /// 단축키만 있는 탭 (패널/팔레트/클립보드/전송) — 칩+실행+복원 1행
    @ViewBuilder
    private var hotkeyOnlySection: some View {
        if let slot = slot(for: selectedTab) {
            groupBox(slot.title) {
                hotkeyRow(slot)
            }
        }
    }

    /// 단축키 1행 — 칩 탭하면 변경, ▶은 직접 실행, ↺는 복원
    private func hotkeyRow(_ slot: HotkeySlot) -> some View {
        HStack(spacing: 8) {
            Text(slot.title)
                .font(.body)
            Spacer()
            Button {
                recordingSlot = slot
            } label: {
                Text(slot.current.displayString)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(theme.tertiaryBackground.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("settings.menubar_icons.change".localized)
            Button {
                slot.test()
            } label: {
                Label("settings.hotkey.try_it".localized, systemImage: "play.fill")
                    .font(.callout)
                    .foregroundColor(theme.accentColor)
            }
            .buttonStyle(.plain)
            Button {
                slot.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13))
                    .foregroundColor(theme.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("settings.menubar_icons.reset".localized)
        }
        .padding(.vertical, 2)
    }

    // MARK: - 일반 탭

    @ViewBuilder
    private var generalSections: some View {
        groupBox("settings.display") {
            toggleRow("settings.show_in_menubar",
                      isOn: menuBarBinding,
                      description: "settings.show_in_menubar.description")
            toggleRow("settings.show_in_dock",
                      isOn: dockBinding,
                      description: "settings.show_in_dock.description")
        }
        groupBox("settings.general.startup") {
            HStack {
                Text("settings.launch_at_login".localized).font(.body)
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { _, newValue in
                        applyLaunchAtLogin(newValue)
                    }
            }
            .padding(.vertical, 2)
            toggleRow("settings.show_hidden_apps", isOn: $store.showHiddenApps)
            toggleRow("settings.show_system_apps", isOn: $store.showSystemApps)
        }
        groupBox("settings.toast") {
            toggleRow("settings.toast.success",
                      isOn: $store.showSuccessToast,
                      description: "settings.toast.success.description")
        }
        groupBox("update.section") {
            HStack {
                updateStatusText
                Spacer()
                if case .checking = store.updateState {
                    ProgressView().controlSize(.small)
                } else {
                    Button("update.check".localized) {
                        Task {
                            let hasUpdate = await store.checkForUpdate()
                            if hasUpdate { showUpdateSheet = true }
                        }
                    }
                }
            }
            .padding(.vertical, 2)
            HStack {
                Text("update.frequency".localized).font(.body)
                Spacer()
                Picker("", selection: Binding(
                    get: { store.updateCheckFrequency },
                    set: { store.updateCheckFrequency = $0 }
                )) {
                    ForEach(ConfigStore.UpdateCheckFrequency.allCases) { frequency in
                        Text(frequency.displayName).tag(frequency)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            if let checkedAt = store.updateCheckedAt {
                Text("update.last_checked".localizedFormat(checkedAt.formatted(date: .abbreviated, time: .shortened)))
                    .font(.caption).foregroundColor(theme.secondaryText)
                    .padding(.leading, 2)
            }
        }
        groupBox("settings.permissions") {
            HStack {
                Text("settings.permissions.accessibility".localized).font(.body)
                Spacer()
                Button(PermissionHelper.isAccessibilityTrusted ? "settings.permissions.accessibility.granted".localized : "settings.permissions.accessibility.request".localized) {
                    PermissionHelper.requestAccessibility()
                }
                .disabled(PermissionHelper.isAccessibilityTrusted)
            }
            .padding(.vertical, 2)
            caption("settings.permissions.accessibility.description")
        }
        groupBox("settings.language") {
            HStack {
                Text("settings.language".localized).font(.body)
                Spacer()
                Picker("", selection: Binding(
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
                .labelsHidden()
            }
            if showRestartBanner {
                HStack {
                    Image(systemName: "arrow.clockwise").foregroundColor(.orange)
                    Text("settings.language.restart_required".localized)
                        .font(.caption).foregroundColor(.orange)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - HUD 탭

    @ViewBuilder
    private var hudSections: some View {
        groupBox("settings.menu_hud") {
            if let slot = slot(for: .hud) {
                hotkeyRow(slot)
            }
        }
        groupBox("settings.menu_hud.display") {
            HStack {
                Text("settings.menu_hud.style".localized).font(.body)
                Spacer()
                Picker("", selection: Binding(
                    get: { store.menuHUDStyle },
                    set: { store.setMenuHUDStyle($0) }
                )) {
                    ForEach(ConfigStore.MenuHUDStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .labelsHidden()
            }
            .padding(.vertical, 2)
            toggleRow("ui.hud.show_no_shortcut",
                      isOn: Binding(
                        get: { store.showNoShortcutItems },
                        set: { store.showNoShortcutItems = $0 }
                      ),
                      description: "settings.hud.show_no_shortcut.description")
        }
    }

    // MARK: - 메뉴바 아이콘 탭

    @ViewBuilder
    private var iconsSections: some View {
        groupBox("menubar.icons.title") {
            if let slot = slot(for: .icons) {
                hotkeyRow(slot)
            }
        }
        groupBox("settings.menubar_icons.grid") {
            HStack {
                Text("settings.menubar_icons.per_row_label".localized).font(.body)
                Spacer()
                Stepper("settings.menubar_icons.per_row_value".localizedFormat(store.menuBarIconsPerRow),
                        value: $store.menuBarIconsPerRow, in: 1...16)
            }
            .padding(.vertical, 2)
            toggleRow("settings.menubar_icons.swap_clicks",
                      isOn: $store.menuBarIconsSwapClicks,
                      description: "settings.menubar_icons.swap_clicks.description")
        }
    }

    // MARK: - 테마 탭

    @ViewBuilder
    private var themeSections: some View {
        ThemeSettingsView()
    }

    // MARK: - 기존 로직 (유지)

    @ViewBuilder
    private var updateStatusText: some View {
        switch store.updateState {
        case .idle:
            Text("update.check".localized)
                .foregroundColor(theme.secondaryText)
        case .checking:
            Text("update.checking".localized)
                .foregroundColor(theme.secondaryText)
        case .upToDate:
            Text("update.up_to_date".localized)
        case let .updateAvailable(tag, _, _):
            Text("update.available".localizedFormat(tag))
                .foregroundColor(.orange)
        case let .unavailable(key):
            Text(key.localized)
                .foregroundColor(.red)
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
