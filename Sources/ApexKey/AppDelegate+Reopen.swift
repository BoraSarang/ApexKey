import AppKit

/// 무아이콘 모드 복구 경로 — 재실행/실행 시 설정 창에 도달하게 한다.
extension AppDelegate {
    /// Finder·Spotlight·Dock에서 이미 실행 중인 앱을 다시 열었을 때.
    /// 아이콘이 모두 꺼져 있으면 설정 창이 유일한 입구다.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let visible = userFacingWindows.filter(\.isVisible)
        Logger.info("AppDelegate", "[REOPEN] 재실행 수신 (visibleWindows=\(visible.count))")

        switch ReopenRouter.reopen(hasVisibleWindow: !visible.isEmpty) {
        case .bringForward:
            NSApp.activate(ignoringOtherApps: true)
            for window in visible {
                window.orderFrontRegardless()
            }
        case .settings:
            showSettingsPanel(nil)
        }
        return true
    }

    /// 앱이 꺼진 상태에서 수동 실행했을 때, 아이콘이 모두 꺼져 있으면 설정 창을 1회 띄운다.
    /// 로그인 자동 시작은 조용히 숨김을 유지한다.
    func showSettingsOnLaunchIfNeeded() {
        guard let store else { return }
        let launchedAsLoginItem = LaunchContext.isLoginItemLaunch()
        guard ReopenRouter.launch(
            showInMenuBar: store.showInMenuBar,
            showInDock: store.showInDock,
            launchedAsLoginItem: launchedAsLoginItem
        ) == .settings else {
            if launchedAsLoginItem {
                Logger.info("AppDelegate", "[LAUNCH] 로그인 자동 시작 — 아이콘 없이 숨김 유지")
            }
            return
        }
        Logger.info("AppDelegate", "[LAUNCH] 아이콘 없음 + 수동 실행 → 설정 창")
        showSettingsPanel(nil)
    }

    /// 재실행 판정에 쓰는 사용자 대상 창. 토스트 같은 일회성 패널은 제외한다.
    private var userFacingWindows: [NSWindow] {
        [panel, settingsWindow, onboardingWindow, aboutWindow, debugWindow,
         paletteWindow, conflictWindow, menuHUDWindow, menuBarIconsWindow,
         editorWindow, stepSettingsWindow, stepTestResultWindow, updateWindow]
            .compactMap { $0 }
    }
}
