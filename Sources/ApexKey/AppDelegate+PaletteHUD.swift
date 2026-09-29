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
            // TextField에 포커스가 안 잡혀 입력이 안 됨 (Menu HUD와 동일 패턴)
            let win = KeyCapablePanel(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 380),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
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
            win.styleMask = [.borderless]

            guard let store else { return }
            let hosting = NSHostingController(rootView: ThemedRoot { CommandPaletteView() }.environmentObject(store))
            paletteHosting = hosting
            win.contentViewController = hosting

            if let screen = Self.screen(for: win) {
                let r = screen.visibleFrame
                let x = r.midX - win.frame.width / 2
                let y = r.midY - win.frame.height / 2
                win.setFrameOrigin(NSPoint(x: x, y: y))
            }

            win.delegate = self
            paletteWindow = win
        }
        guard let win = paletteWindow else { return }
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        win.level = NSWindow.Level(rawValue: 25)
    }

    func hidePalettePanel() {
        paletteWindow?.orderOut(nil)
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
        // 서브메뉴는 부모 노드 포함, 깊이 보존해서 평탄화 — HUD 계층(indent) 표시용
        let menuEntries = MenuEnumerator.shared.flattenedWithDepth(in: items)
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

    /// HUD에서 항목 실행 — AppleScript 메뉴 클릭 후 닫기
    func runMenuItem(_ item: MenuItem, in bundleID: String) {
        let result = MenuEnumerator.shared.performAction(item, in: bundleID)
        Logger.info("AppDelegate", "[HUD] 항목 실행 \(result.isSuccess ? "성공" : "실패"): \(item.title)")
        hideMenuHUD()
    }

    func hideMenuHUD() {
        menuHUDWindow?.orderOut(nil)
        menuHUDOverlayWindow?.orderOut(nil)
        Logger.info("AppDelegate", "[HUD] 닫기")
    }

    /// 화면 상단 1/3 지점(중앙)에 고정 크기로 HUD 배치
    func placeMenuHUD(_ win: NSPanel) {
        guard let screen = Self.screen(for: win) else { return }
        let visible = screen.visibleFrame
        let x = visible.midX - 230
        let y = visible.maxY - 420 - 120
        win.setFrame(NSRect(x: x, y: y, width: 460, height: 420), display: true)
        win.layoutIfNeeded()
    }
}
