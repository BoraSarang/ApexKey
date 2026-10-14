import SwiftUI
import AppKit
import ServiceManagement

/// Hub 치수 단일 출처 — View frame(340×492) + 패딩(10) = popover contentSize(360×512).
/// 한쪽만 바꾸면 팝오버에 빈틈/잘림이 생기므로 여기로만 수정한다.
enum HubMetrics {
    static let contentWidth: CGFloat = 340
    static let contentHeight: CGFloat = 492
    static let padding: CGFloat = 10
    static var popoverSize: NSSize {
        NSSize(width: contentWidth + padding * 2, height: contentHeight + padding * 2)
    }
}

/// 메뉴바 Hub 팝오버 액션 — AppDelegate가 팝오버를 먼저 닫고 수행한다
/// (PickBeon `menuAction { dismissMenu?(); work() }` 패턴).
enum MenuHubAction {
    case openPalette
    case repeatLast
    case openClipboard
    case menuHUD
    case menuBarIcons
    case openPanel
    case newShortcut
    case openSettings
    case checkUpdate
    case editLatest
    case terminate
}

/// 메뉴바 Hub — PickBeon식 실행/설정 2탭 팝오버 (좌클릭 기본 화면).
/// 메인 창 토글을 대체한다: 작은 transient 팝오버라 실수 클릭 피해가 없고,
/// 모든 행 액션은 AppDelegate.hubAction에서 팝오버를 닫은 뒤 수행된다.
struct MenuHubView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var tab: HubTab = .run

    /// AppDelegate가 주입하는 단일 디스패치 (닫기+실행 보장용).
    var onAction: (MenuHubAction) -> Void = { _ in }

    private enum HubTab: String, CaseIterable {
        case run, settings
        var label: String {
            switch self {
            case .run: "hub.run_tab".localized
            case .settings: "hub.settings_tab".localized
            }
        }
    }

    /// 마지막 실행 단축키 — 최신행·편집 진입 공용. 순수 함수라 테스트 가능.
    static func latestRun(in shortcuts: [ShortcutItem]) -> ShortcutItem? {
        shortcuts
            .filter { $0.lastRunAt != nil }
            .max { ($0.lastRunAt ?? .distantPast) < ($1.lastRunAt ?? .distantPast) }
    }

    private var latest: ShortcutItem? { Self.latestRun(in: store.shortcuts) }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            ScrollView {
                tabContent
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            Divider()
            footer
        }
        .frame(width: HubMetrics.contentWidth, height: HubMetrics.contentHeight)
        .background(theme.primaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, HubMetrics.padding)
        .padding(.vertical, HubMetrics.padding)
    }

    // MARK: - 헤더 + 탭

    private var tabBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "command.square.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.blue.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text("ApexKey").font(.system(size: 14, weight: .bold))
                .foregroundStyle(theme.primaryText)
            Spacer()
            HStack(spacing: 2) {
                ForEach(HubTab.allCases, id: \.rawValue) { t in
                    let isOn = tab == t
                    Text(t.label)
                        .font(.system(size: 12, weight: isOn ? .semibold : .medium))
                        .foregroundStyle(isOn ? Color.white : theme.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isOn ? Color.blue : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { tab = t } }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .run: runTab
        case .settings: settingsTab
        }
    }

    // MARK: - 실행 탭

    private var runTab: some View {
        VStack(spacing: 6) {
            heroButton
            hubRow(icon: "circle.grid.2x2",
                   title: "hub.menu_bar_icons".localized,
                   sub: "hub.menu_bar_icons.sub".localized,
                   combo: store.menuBarIconsHotkey) {
                onAction(.menuBarIcons)
            }
            hubRow(icon: "doc.on.clipboard",
                   title: "hub.clipboard".localized,
                   sub: "hub.clipboard.sub".localized,
                   combo: store.clipboardHotkey) {
                onAction(.openClipboard)
            }
            hubRow(icon: "menubar.rectangle",
                   title: "hub.menu_hud".localized,
                   sub: "hub.menu_hud.sub".localized,
                   combo: store.menuHUDHotkey) {
                onAction(.menuHUD)
            }
            hubRow(icon: "macwindow",
                   title: "hub.open_panel".localized,
                   sub: "hub.open_panel.sub".localized,
                   combo: store.toggleHotkey) {
                onAction(.openPanel)
            }
            hubRow(icon: "plus",
                   title: "hub.new_shortcut".localized,
                   sub: "hub.new_shortcut.sub".localized,
                   combo: nil) {
                onAction(.newShortcut)
            }
            latestRow
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    /// 주 액션 — 명령 팔레트 (실제 기본 핫키 표시).
    private var heroButton: some View {
        Button { onAction(.openPalette) } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 1) {
                    Text("hub.open_palette".localized)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(.white)
                    Text("hub.open_palette.sub".localized)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                Text(store.paletteHotkey.displayString)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.gradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }

    private func hubRow(icon: String, title: String, sub: String,
                       combo: HotKeyCombo?, _ action: @escaping () -> Void) -> some View {
        HubRowButton(icon: icon, title: title, sub: sub, combo: combo, action: action)
            .padding(.horizontal, 12)
    }

    // MARK: - 최신 실행 한 줄

    private var latestRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(latest == nil ? theme.tertiaryText : Color.green)
                .frame(width: 6, height: 6)
            if let latest {
                (Text("hub.latest.just".localized + " — ")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    + Text(latest.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(theme.primaryText))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Button { onAction(.repeatLast) } label: {
                    Image(systemName: "repeat")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.blue)
                        .frame(width: 24, height: 24)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("hub.repeat_last".localized)
                Button { onAction(.editLatest) } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.secondaryText)
                        .frame(width: 24, height: 24)
                        .background(theme.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("hub.latest.edit_help".localized)
            } else {
                Text("hub.latest.none".localized)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(theme.tertiaryBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 12)
    }

    // MARK: - 설정 탭

    private var settingsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { onAction(.openSettings) } label: {
                HStack(spacing: 11) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.blue)
                        .frame(width: 24, height: 24)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("hub.open_settings_all".localized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.primaryText)
                        Text("hub.open_settings_all.sub".localized)
                            .font(.system(size: 11.5))
                            .foregroundStyle(theme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(11)
                .background(theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 11))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)

            quickToggle("hub.toggle.always_on_top".localized, $store.alwaysOnTop)
            quickToggle("hub.toggle.launch_at_login".localized, launchAtLoginBinding)
            quickToggle("hub.toggle.success_toast".localized, $store.showSuccessToast)
            quickToggle("hub.toggle.menu_bar".localized, menuBarBinding)

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
                Text("hub.toggle.hint".localized)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 2)
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private func quickToggle(_ title: String, _ bind: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(theme.primaryText)
            Spacer()
            Toggle("", isOn: bind)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(theme.cardBackground.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 12)
    }

    /// 메뉴바 토글 — Dock도 꺼져 있으면 거부돼 값이 그대로라 토글이 원위치한다.
    private var menuBarBinding: Binding<Bool> {
        Binding(
            get: { store.showInMenuBar },
            set: { _ = store.setMenuBarVisible($0) }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { enabled in
                let service = SMAppService.mainApp
                do {
                    if enabled {
                        try service.register()
                    } else {
                        try service.unregister()
                    }
                    launchAtLogin = enabled
                } catch {
                    Logger.error("E-MAC-LOGIN-7001", "로그인 시작 설정 실패: \(error.localizedDescription)")
                }
            }
        )
    }

    // MARK: - 푸터

    private var footer: some View {
        HStack(spacing: 8) {
            Text("ApexKey v\(ReleaseChecker.currentVersion)")
                .font(.system(size: 11.5))
                .foregroundStyle(theme.secondaryText.opacity(0.7))
            Spacer()
            switch tab {
            case .run:
                if let update = store.availableUpdate {
                    Button { onAction(.checkUpdate) } label: {
                        Text("hub.update_available".localizedFormat(update.tagName))
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Color.orange)
                    }
                    .buttonStyle(.plain)
                }
                footerTap("hub.footer.settings".localized) { onAction(.openSettings) }
            case .settings:
                if let update = store.availableUpdate {
                    Button { onAction(.checkUpdate) } label: {
                        Text("hub.update_available".localizedFormat(update.tagName))
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Color.orange)
                    }
                    .buttonStyle(.plain)
                } else {
                    footerTap("hub.footer.check_update".localized) { onAction(.checkUpdate) }
                }
            }
            footerTap("ui.quit".localized) { onAction(.terminate) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private func footerTap(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(theme.secondaryText)
        }
        .buttonStyle(.plain)
    }
}

/// Hub 실행 행 — hover 강조 + 목업식 단일-필 키캡.
/// KeycapView 기본(멀티캡)은 행을 키우므로 Hub에선 할당-강조 단일캡슐을 쓴다.
private struct HubRowButton: View {
    @Environment(\.theme) private var theme
    let icon: String
    let title: String
    let sub: String
    let combo: HotKeyCombo?
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.blue)
                    .frame(width: 22, height: 22)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 2)
                if let combo, !combo.isEmpty {
                    KeycapView(combo: combo, highlighted: true)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(hovering ? theme.cardBackground.opacity(1) : theme.cardBackground.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(hovering ? theme.focusBorder.opacity(0.6) : theme.cardBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
