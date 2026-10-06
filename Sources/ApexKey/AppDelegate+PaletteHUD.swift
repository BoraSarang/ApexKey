//
//  AppDelegate+PaletteHUD.swift
//  ApexKey
//
//  Command palette and menu HUD overlays
//

import AppKit
import SwiftUI
import Combine

extension AppDelegate {
    // MARK: - 명령 팔레트 (⌘⌥K)

    func showPalettePanel() {
        if paletteWindow == nil {
            // KeyCapablePanel 필수: borderless NSPanel은 canBecomeKey=false라
            // TextField에 포커스가 안 잡혀 입력이 안 됨 (Menu HUD와 동일 패턴).
            // 처음부터 borderless로 생성 — titled로 만들었다가 바꾸면 frame/content
            // 매핑이 어긋나 내용이 잘린다.
            let win = KeyCapablePanel(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 400),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            win.title = "Command Palette"
            win.isFloatingPanel = true
            // 타 오버레이(런처류 플로팅 패널)에 가려지지 않도록 status 레벨 유지
            win.level = NSWindow.Level(rawValue: 25)
            win.isMovableByWindowBackground = false
            win.hidesOnDeactivate = false
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            win.hasShadow = true
            win.backgroundColor = .clear
            win.isOpaque = false

            guard let store else { return }
            let hosting = NSHostingController(rootView: ThemedRoot { CommandPaletteView() }.environmentObject(store))
            paletteHosting = hosting
            win.contentViewController = hosting
            win.setContentSize(NSSize(width: 560, height: 400))

            win.delegate = self
            paletteWindow = win
        }
        guard let win = paletteWindow else { return }
        // 고정 크기 복원 (이전 동적 리사이즈 잔재 제거) 후 매번 화면 중앙 배치
        win.setContentSize(NSSize(width: 560, height: 400))
        centerPaletteWindow(win)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        win.level = NSWindow.Level(rawValue: 25)
    }

    /// 팔레트 중앙 배치 — 열 때마다 화면 중앙으로 (위치 기억 안 함).
    /// visibleFrame 기준이라 메뉴바/Dock에 가리지 않는다.
    private func centerPaletteWindow(_ win: NSPanel) {
        let screen = win.screen ?? Self.screen(for: nil) ?? NSScreen.main
        guard let screen else { return }
        let r = screen.visibleFrame
        win.setFrameOrigin(NSPoint(
            x: r.origin.x + (r.width - win.frame.width) / 2,
            y: r.origin.y + (r.height - win.frame.height) / 2
        ))
    }

    func hidePalettePanel() {
        paletteWindow?.orderOut(nil)
    }

    // MARK: - Conflict palette (공유 단축키 선택)

    /// 같은 조합의 실행 후보가 여러 건이면 선택 패널 표시.
    /// onPick/onPin은 ConfigStore 실행 경로로 그대로 위임한다.
    func showConflictPanel(combo: HotKeyCombo, targets: [HotKeyConflict.Target]) {
        guard let store else { return }
        NSApp.activate(ignoringOtherApps: true)
        let view = ConflictPaletteView(
            comboDisplay: combo.displayString,
            targets: targets,
            onPick: { [weak self] target in
                self?.conflictWindow?.orderOut(nil)
                self?.store?.runConflictTarget(target)
            },
            onPin: { [weak self] target in
                HotKeyConflict.setPreferred(target.id, for: combo)
                self?.conflictWindow?.orderOut(nil)
                self?.store?.runConflictTarget(target)
                Logger.info("ConfigStore", "[HOTKEY] 공유 고정: \(combo.displayString) → \(target.title)")
            }
        )
        let hosting = NSHostingController(rootView: ThemedRoot { view }.environmentObject(store))
        conflictHosting = hosting
        let win: NSPanel
        if let existing = conflictWindow {
            win = existing
            win.contentViewController = hosting
        } else {
            let w = KeyCapablePanel(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            w.isFloatingPanel = true
            w.level = NSWindow.Level(rawValue: 25)
            w.hidesOnDeactivate = false
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            w.hasShadow = true
            w.backgroundColor = .clear
            w.isOpaque = false
            w.contentViewController = hosting
            w.delegate = self
            conflictWindow = w
            win = w
        }
        if let screen = Self.screen(for: win) {
            let r = screen.visibleFrame
            win.setFrameOrigin(NSPoint(
                x: r.origin.x + (r.width - win.frame.width) / 2,
                y: r.origin.y + (r.height - win.frame.height) / 2
            ))
        }
        win.makeKeyAndOrderFront(nil)
    }

    // MARK: - Menu HUD (전면 앱 단축키 표시)

    @objc func toggleMenuHUD() {
        if (menuHUDWindow?.isVisible ?? false) || (menuHUDOverlayWindow?.isVisible ?? false) {
            hideMenuHUD()
            return
        }
        guard let store else { return }
        // 전면 앱 감지
        guard let front = NSWorkspace.shared.frontmostApplication,
              let bundleID = front.bundleIdentifier else {
            Logger.info("AppDelegate", "[HUD] 전면 앱 감지 실패")
            return
        }
        let items = MenuEnumerator.shared.enumerateMenuItems(bundleID: bundleID)
        // Option 대체항목 중복 제거 (M-02) — HUD 표시만 정리, 할당 UI는 원본 유지
        let deduped = MenuEnumerator.shared.removingAlternateDuplicates(in: items)
        // 서브메뉴는 부모 노드 포함, 깊이 보존해서 평탄화 — HUD 계층(indent) 표시용
        let menuEntries = MenuEnumerator.shared.flattenedWithDepth(in: deduped)
        // 메뉴(first 경로)별 그룹화 — 단축키 유무 무관, 모든 메뉴 항목 포함
        var groups: [(menu: String, items: [MenuItem])] = []
        var indexByMenu: [String: Int] = [:]
        for item in menuEntries {
            let menu = item.menuPath.first ?? item.title
            if let idx = indexByMenu[menu] {
                groups[idx].items.append(item)
            } else {
                indexByMenu[menu] = groups.count
                groups.append((menu, [item]))
            }
        }
        let appName = front.localizedName ?? bundleID
        let icon = front.icon

        // 저장된 표시 방식으로 분기
        switch store.menuHUDStyle {
        case .floatingWindow:
            showMenuHUDFloating(appName: appName, icon: icon, groups: groups, bundleID: bundleID, count: menuEntries.count)
        case .fullscreen:
            showMenuHUDOverlay(appName: appName, icon: icon, groups: groups, bundleID: bundleID, count: menuEntries.count)
        }
    }

    /// HUD 표시 방식 1 — 기존 플로팅 창 (460x420)
    func showMenuHUDFloating(appName: String, icon: NSImage?, groups: [(menu: String, items: [MenuItem])], bundleID: String, count: Int) {
        guard let store = self.store else { return }
        let view = MenuCheatSheetView(appName: appName, appIcon: icon, groups: groups) { [weak self] in
            self?.hideMenuHUD()
        } onRun: { [weak self] item in
            self?.runMenuItem(item, in: bundleID)
        }
        let hosting = NSHostingController(rootView: ThemedRoot { view }.environmentObject(store))
        menuHUDHosting = hosting

        if menuHUDWindow == nil {
            let win = KeyCapablePanel(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 380),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            win.isFloatingPanel = true
            win.level = .floating
            win.hidesOnDeactivate = true
            win.isOpaque = false
            win.backgroundColor = .clear
            win.hasShadow = false
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            win.contentViewController = hosting
            win.setContentSize(NSSize(width: 460, height: 420))
            win.delegate = self
            menuHUDWindow = win
        } else if let win = menuHUDWindow {
            win.contentViewController = hosting
            win.setContentSize(NSSize(width: 460, height: 420))
        }

        guard let win = menuHUDWindow else { return }
        placeMenuHUD(win)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        Logger.info("AppDelegate", "[HUD] 플로팅 창 표시: \(appName) (\(count)개)")
    }

    /// HUD 표시 방식 2 — 전체 화면 KeyCue 오버레이
    func showMenuHUDOverlay(appName: String, icon: NSImage?, groups: [(menu: String, items: [MenuItem])], bundleID: String, count: Int) {
        guard let store = self.store else { return }
        let view = MenuHUDOverlayView(appName: appName, appIcon: icon, groups: groups) { [weak self] in
            self?.hideMenuHUD()
        } onRun: { [weak self] item in
            self?.runMenuItem(item, in: bundleID)
        }
        let hosting = NSHostingController(rootView: ThemedRoot { view }.environmentObject(store))
        menuHUDOverlayHosting = hosting

        if menuHUDOverlayWindow == nil {
            let win = KeyCapablePanel(
                contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            win.isFloatingPanel = true
            win.level = .floating
            win.hidesOnDeactivate = true
            win.isOpaque = false
            win.backgroundColor = .clear
            win.hasShadow = false
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            win.contentViewController = hosting
            win.delegate = self
            menuHUDOverlayWindow = win
        } else if let win = menuHUDOverlayWindow {
            win.contentViewController = hosting
        }

        guard let win = menuHUDOverlayWindow, let screen = Self.screen(for: win) ?? NSScreen.main else { return }
        // 전체 화면 프레임 (메뉴바 포함해 덮음)
        win.setFrame(screen.frame, display: true)
        win.layoutIfNeeded()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        Logger.info("AppDelegate", "[HUD] 전체 화면 표시: \(appName) (\(count)개)")
    }

    /// HUD 실행 결과 토스트 정책 (M-05) — 순수 판정, 테스트 고정용.
    /// 실패만 토스트하고 성공은 nil. 성공 시 표시 여부는 showToast의 showSuccessToast 정책에 맡긴다.
    enum MenuHUDRunFeedback {
        static func toastMessage(for result: MenuActionResult) -> String? {
            result.isSuccess ? nil : result.description
        }
    }

    /// HUD에서 항목 실행 — AppleScript 메뉴 클릭 후 닫기.
    /// 실패하면 조용히 닫지 않고 이유를 토스트로 알린다 (M-05).
    /// 성공은 기존 showSuccessToast 정책을 따른다.
    func runMenuItem(_ item: MenuItem, in bundleID: String) {
        let result = MenuEnumerator.shared.performAction(item, in: bundleID)
        Logger.info("AppDelegate", "[HUD] 항목 실행 \(result.isSuccess ? "성공" : "실패"): \(item.title)")
        hideMenuHUD()
        if let message = Self.MenuHUDRunFeedback.toastMessage(for: result) {
            showToast(title: item.title, message: message, success: false)
        }
    }

    func hideMenuHUD() {
        menuHUDWindow?.orderOut(nil)
        menuHUDOverlayWindow?.orderOut(nil)
        Logger.info("AppDelegate", "[HUD] 닫기")
    }

    // MARK: - Menu Bar Icons 그리드 (M-03 UI)

    @objc func toggleMenuBarIcons() {
        if menuBarIconsWindow?.isVisible ?? false {
            hideMenuBarIcons()
            return
        }
        guard let store else { return }
        guard PermissionHelper.isAccessibilityTrusted else {
            showToast(title: "menubar.icons.title".localized,
                      message: "menubar.icons.no_permission".localized, success: false)
            return
        }
        // stale-while-revalidate: 낡은 목록이라도 즉시 보여주고 뒤에서 갱신.
        // 캐시가 전혀 없을 때만 기다린다 (첫 열기 — 실행 시 예열로 대부분 커버).
        if let cached = MenuBarIconEnumerator.shared.cachedIcons(), !cached.isEmpty {
            showMenuBarIcons(cached, store: store)
            return
        }
        if let stale = MenuBarIconEnumerator.shared.staleIcons() {
            showMenuBarIcons(stale, store: store)
            refreshMenuBarIconsInBackground()
            return
        }
        Task {
            let icons = await MenuBarIconEnumerator.shared.enumerateAsync()
            await MainActor.run {
                guard !icons.isEmpty else {
                    self.showToast(title: "menubar.icons.title".localized,
                                   message: "menubar.icons.empty".localized, success: false)
                    return
                }
                // 열리는 동안 사용자가 닫았으면 덮어쓰지 않는다
                guard !(self.menuBarIconsWindow?.isVisible ?? false),
                      let store = self.store else { return }
                self.showMenuBarIcons(icons, store: store)
            }
        }
    }

    /// 백그라운드 갱신 — 열려 있는 그리드가 있으면 그 자리에서 교체한다.
    private func refreshMenuBarIconsInBackground() {
        Task {
            let icons = await MenuBarIconEnumerator.shared.enumerateAsync()
            await MainActor.run {
                guard !icons.isEmpty,
                      self.menuBarIconsWindow?.isVisible ?? false,
                      let store = self.store else { return }
                self.showMenuBarIcons(icons, store: store)
            }
        }
    }

    private func showMenuBarIcons(_ icons: [MenuBarIconEnumerator.IconItem], store: ConfigStore) {
        let view = MenuBarIconsGridView(icons: icons, columns: store.menuBarIconsPerRow,
                                        swapClicks: store.menuBarIconsSwapClicks) { [weak self] in
            self?.hideMenuBarIcons()
        } onActivate: { [weak self] item, rightClick in
            self?.activateMenuBarIcon(item, rightClick: rightClick)
        }
        let hosting = NSHostingController(rootView: ThemedRoot { view }.environmentObject(store))
        menuBarIconsHosting = hosting

        if menuBarIconsWindow == nil {
            let win = KeyCapablePanel(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 400),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            win.isFloatingPanel = true
            win.level = .floating
            win.hidesOnDeactivate = true
            win.isOpaque = false
            win.backgroundColor = .clear
            win.hasShadow = false
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            win.contentViewController = hosting
            win.setContentSize(NSSize(width: 560, height: 400))
            win.delegate = self
            menuBarIconsWindow = win
        } else if let win = menuBarIconsWindow {
            win.contentViewController = hosting
            win.setContentSize(NSSize(width: 560, height: 400))
        }

        guard let win = menuBarIconsWindow else { return }
        placeMenuHUD(win)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        Logger.info("AppDelegate", "[ICONS] 그리드 표시 (\(icons.count)개)")
    }

    /// 그리드에서 아이콘 활성화 — 실제 아이콘 클릭 후 닫기, 실패만 토스트 (M-05 패턴)
    func activateMenuBarIcon(_ item: MenuBarIconEnumerator.IconItem, rightClick: Bool) {
        let result = MenuBarIconEnumerator.shared.click(item, rightClick: rightClick)
        Logger.info("AppDelegate", "[ICONS] 아이콘 활성화 \(result.isSuccess ? "성공" : "실패"): \(item.title)")
        hideMenuBarIcons()
        if let message = result.toastMessage {
            showToast(title: item.title, message: message, success: false)
        }
    }

    func hideMenuBarIcons() {
        menuBarIconsWindow?.orderOut(nil)
        Logger.info("AppDelegate", "[ICONS] 닫기")
    }

    /// 포인터 adjacent 배치 (M-01) — 커서 오른쪽·아래 우선, 화면 밖이면 뒤집고 클램프.
    /// 전체화면 오버레이는 화면을 덮으므로 대상 아님 (플로팅 창 전용).
    func placeMenuHUD(_ win: NSPanel) {
        guard let screen = Self.screen(for: win) else { return }
        let frame = Self.anchoredFrame(near: NSEvent.mouseLocation,
                                       size: win.frame.size,
                                       in: screen.visibleFrame)
        win.setFrame(frame, display: true)
        win.layoutIfNeeded()
    }
}
