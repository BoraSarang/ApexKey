//
//  AppDelegate+Hub.swift
//  ApexKey
//
//  Menu Hub popover (PickBeon parity) — left-click shows the Hub,
//  right-click keeps the legacy NSMenu.
//

import AppKit
import SwiftUI
import Combine

extension AppDelegate {
    // MARK: - Hub 팝오버 (좌클릭)

    private func makeHubPopover(store: ConfigStore) -> NSPopover {
        let popover = NSPopover()
        let hosting = NSHostingController(rootView:
            ThemedRoot { [weak self] in
                MenuHubView { [weak self] action in
                    self?.hubAction(action)
                }
            }.environmentObject(store)
        )
        hubHosting = hosting
        popover.contentViewController = hosting
        popover.contentSize = HubMetrics.popoverSize
        popover.behavior = .transient
        popover.animates = true
        hubPopover = popover
        return popover
    }

    /// 좌클릭 → Hub 토글. transient라 바깥 클릭·Esc로 닫힌다.
    /// 예전 togglePanel()과 달리 포커스를 뺏는 거대 창을 열지 않는다.
    func toggleHub() {
        if let popover = hubPopover, popover.isShown {
            Logger.info("AppDelegate", "[HUB] 닫기")
            popover.performClose(nil)
            return
        }
        guard let button = statusItem?.button, let store else { return }
        let popover = hubPopover ?? makeHubPopover(store: store)
        Logger.info("AppDelegate", "[HUB] 열기")
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        applyHubPopoverMaterial(popover)
        Task {
            await store.maybeAutoCheckForUpdate()
        }
    }

    func dismissHub() {
        hubPopover?.performClose(nil)
    }

    /// Hub 행 액션 — 팝오버를 먼저 닫고 수행한다
    /// (PickBeon `menuAction { dismissMenu?(); work() }` 패턴).
    func hubAction(_ action: MenuHubAction) {
        dismissHub()
        guard let store else { return }
        switch action {
        case .openPalette:
            store.paletteMode = .normal
            store.showPalette = true
            // 이미 true면 sink가 안 타므로 직접 front 보장
            showPalettePanel()
            Logger.info("AppDelegate", "[HUB] 명령 팔레트 열기")
        case .repeatLast:
            store.repeatLastBinding()
        case .openClipboard:
            store.paletteMode = .clipboard
            ClipboardMonitor.shared.refresh()
            store.showPalette = true
            showPalettePanel()
            Logger.info("AppDelegate", "[HUB] 클립보드 기록 열기")
        case .menuHUD:
            toggleMenuHUD()
        case .menuBarIcons:
            toggleMenuBarIcons()
        case .openPanel:
            openPanelOnly()
        case .newShortcut:
            if let created = store.addShortcut(name: "palette.cmd.new_shortcut.name".localized) {
                showEditor(for: created)
            }
        case .openSettings:
            showSettingsPanel(nil)
        case .checkUpdate:
            checkForUpdateAction(nil)
        case .editLatest:
            if let latest = MenuHubView.latestRun(in: store.shortcuts),
               let current = store.shortcuts.first(where: { $0.id == latest.id }) {
                showEditor(for: current)
            }
        case .terminate:
            NSApp.terminate(nil)
        }
    }

    /// 팝오버 유리 재질 강제 — PickBeon applyPopoverMaterial 이식.
    /// contentViewController.view의 superview 체인을 타고 올라가
    /// 첫 NSVisualEffectView를 popover 재질로 고정한다.
    private func applyHubPopoverMaterial(_ popover: NSPopover) {
        var view = popover.contentViewController?.view.superview
        while let v = view {
            if let effect = v as? NSVisualEffectView {
                effect.material = .popover
                effect.blendingMode = .behindWindow
                effect.state = .active
                return
            }
            view = v.superview
        }
    }
}
