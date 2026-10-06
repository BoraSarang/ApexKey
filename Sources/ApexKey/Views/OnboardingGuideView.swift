import SwiftUI

/// 첫 실행 가이드 (M-06) — A안 변형: 기본값은 그대로 두고 가이드 안에서 바로 수정 가능.
/// 1단계 권한(Accessibility) → 2단계 단축키 확인/수정 → "그대로 시작"이면 통과.
/// 설정 앱의 행·시트와 같은 저장 경로(set*Hotkey)를 쓰므로 단일 출처가 유지된다.
/// 다시 보지 않음: 닫기(빨간 X 포함) 시 완료로 기록 — 다음 실행부터 표시 안 함.
struct OnboardingGuideView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme
    /// 닫기 요청 (AppDelegate가 창 닫기 + 완료 기록)
    var onFinish: () -> Void = {}

    @State private var step = 0
    @State private var recordingSlot: Slot? = nil
    @State private var accessibilityOK = PermissionHelper.isAccessibilityTrusted

    /// 단축키 슬롯 1건 — Settings 행과 같은 저장/테스트 경로
    struct Slot: Identifiable {
        let id: Int
        let title: String
        let current: HotKeyCombo
        let excluded: HotKeyCombo
        let save: (HotKeyCombo) -> String?
        let test: () -> Void
    }

    private func slots() -> [Slot] {
        [
            Slot(id: 0, title: "settings.panel_hotkey".localized, current: store.toggleHotkey,
                 excluded: store.toggleHotkey,
                 save: { store.setPanelToggleHotkey($0).errorMessage },
                 test: { NotificationCenter.default.post(name: .togglePanel, object: nil) }),
            Slot(id: 1, title: "settings.palette".localized, current: store.paletteHotkey,
                 excluded: store.paletteHotkey,
                 save: { store.setPaletteHotkey($0).errorMessage },
                 test: { store.showPalette.toggle() }),
            Slot(id: 2, title: "settings.menu_hud".localized, current: store.menuHUDHotkey,
                 excluded: store.menuHUDHotkey,
                 save: { store.setMenuHUDHotkey($0).errorMessage },
                 test: { NotificationCenter.default.post(name: .toggleMenuHUD, object: nil) }),
            Slot(id: 3, title: "settings.clipboard".localized, current: store.clipboardHotkey,
                 excluded: store.clipboardHotkey,
                 save: { store.setClipboardHotkey($0).errorMessage },
                 test: { store.paletteMode = .clipboard; store.showPalette.toggle() }),
            Slot(id: 4, title: "settings.send".localized, current: store.sendHotkey,
                 excluded: store.sendHotkey,
                 save: { store.setSendHotkey($0).errorMessage },
                 test: { store.fireInstantSend() }),
            Slot(id: 5, title: "menubar.icons.title".localized, current: store.menuBarIconsHotkey,
                 excluded: store.menuBarIconsHotkey,
                 save: { store.setMenuBarIconsHotkey($0).errorMessage },
                 test: { NotificationCenter.default.post(name: .toggleMenuBarIcons, object: nil) }),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if step == 0 {
                permissionStep
            } else {
                shortcutsStep
            }
            Divider()
            footer
        }
        .frame(width: 480, height: 460)
        .background(theme.cardBackground)
        .onAppear {
            accessibilityOK = PermissionHelper.isAccessibilityTrusted
        }
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
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "command.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(theme.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("onboarding.title".localized)
                    .font(.headline)
                Text(step == 0 ? "onboarding.step1".localized : "onboarding.step2".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - 1단계: 권한

    private var permissionStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(accessibilityOK ? "onboarding.permission.ok".localized : "onboarding.permission.needed".localized,
                  systemImage: accessibilityOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.body)
                .foregroundColor(accessibilityOK ? theme.successColor : theme.warningColor)
            Text("onboarding.permission.description".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if !accessibilityOK {
                Button("onboarding.permission.open_settings".localized) {
                    PermissionHelper.requestAccessibility()
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - 2단계: 단축키 확인/수정

    private var shortcutsStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("onboarding.shortcuts.description".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 6)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(slots()) { slot in
                        HStack {
                            Text(slot.title)
                                .font(.body)
                            Spacer()
                            Text(slot.current.displayString)
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(theme.tertiaryBackground.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            Button("settings.panel_hotkey.change".localized) {
                                recordingSlot = slot
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(theme.accentColor)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var footer: some View {
        HStack {
            if step == 1 {
                Button("onboarding.back".localized) { step = 0 }
                    .buttonStyle(.borderless)
            }
            Spacer()
            if step == 0 {
                Button("onboarding.next".localized) { step = 1 }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("onboarding.start".localized) { onFinish() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

/// 온보딩 완료 플래그 (M-06) — UserDefaults 단일 키, 테스트 주입 가능.
enum OnboardingState {
    static let completedKey = "pref.onboardingCompleted.v1"

    static func isCompleted(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: completedKey)
    }

    static func markCompleted(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: completedKey)
    }
}
