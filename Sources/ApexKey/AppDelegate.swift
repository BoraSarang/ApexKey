import AppKit
import SwiftUI
import Combine

/// 메뉴바 상태 아이템 + 독립 플로팅 창 관리
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// 창이 놓일 화면 — NSScreen.main(key 기준)이 아니라 창 소속→마우스→main→첫 화면 순
    static func screen(for window: NSWindow?) -> NSScreen? {
        if let win = window, let s = win.screen { return s }
        let mouse = NSEvent.mouseLocation
        if let s = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) { return s }
        return NSScreen.main ?? NSScreen.screens.first
    }

    var statusItem: NSStatusItem?
    var panel: NSPanel?
    var settingsWindow: NSWindow?
    var aboutWindow: NSWindow?
    var debugWindow: NSWindow?
    var paletteWindow: NSPanel?
    var menuHUDWindow: NSPanel?
    var menuHUDOverlayWindow: NSPanel?
    var editorWindow: NSWindow?
    var stepSettingsWindow: NSWindow?
    var stepTestResultWindow: NSWindow?
    var updateWindow: NSWindow?
    // NSWindow.contentViewController는 strong(직접 참조 유지)이지만, NSHostingController가
    // 창 dealloc보다 먼저 해제되는 것을 막기 위해 슈퍼타입으로 안전하게 보관해 둔다.
    var panelHosting: NSViewController?
    var settingsHosting: NSViewController?
    var aboutHosting: NSViewController?
    var debugHosting: NSViewController?
    var paletteHosting: NSViewController?
    var menuHUDHosting: NSViewController?
    var menuHUDOverlayHosting: NSViewController?
    var editorHosting: NSViewController?
    var stepSettingsHosting: NSViewController?
    var stepTestResultHosting: NSViewController?
    var updateHosting: NSViewController?
    var toastHosting: NSViewController?
    var toastWindow: NSPanel?
    var toastTimer: Timer?
    var store: ConfigStore?
    var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.info("AppDelegate", "[APP] ApexKey 시작 (macOS \(ProcessInfo.processInfo.operatingSystemVersionString))")
        // 설정 창은 AppKit showSettingsPanel(⌘,)가 전담한다. SwiftUI scene 없이
        // AppKit @main으로 기동하므로 시작 시 빈 창이 생성되지 않는다.
        let store = ConfigStore()
        self.store = store

        applyActivationPolicy(store)
        setupSystemMenu()
        setupStatusItem()
        setupPanel(with: store)
        observe(store)

        // 툴바 설정 버튼 → 설정 창 (Combine으로 MainActor 격리 보장)
        NotificationCenter.default.publisher(for: .openSettings)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.showSettingsPanel(nil)
            }
            .store(in: &cancellables)

        // ⇧⌥A → 메인 패널 토글 (ConfigStore에서 발신)
        NotificationCenter.default.publisher(for: .togglePanel)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.togglePanel()
            }
            .store(in: &cancellables)

        // ⇧⌥S → Menu HUD 토글 (전면 앱 단축키 표시)
        NotificationCenter.default.publisher(for: .toggleMenuHUD)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.toggleMenuHUD()
            }
            .store(in: &cancellables)

        // 업데이트 안내 창 요청 (정보 창·메뉴바에서 발신, AppDelegate가 창 소유)
        NotificationCenter.default.publisher(for: .showUpdateSheet)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.showUpdateWindow()
            }
            .store(in: &cancellables)

        // 앱 실행 시 자동 확인 (주기 due일 때만 조용히 조회, 자동 팝업 없음)
        Task {
            await store.maybeAutoCheckForUpdate()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.info("AppDelegate", "[APP] ApexKey 종료")
    }

    // Dock/파인더 등에서 재실행(open) 시 빈 창을 만들지 않도록, 존재하는 창 중 하나를
    // 앞으로 가져오거나(창이 있을 때) 아무것도 만들지 않는다(메뉴바 앱).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Logger.info("AppDelegate", "[REOPEN] 재실행 수신 (hasVisibleWindows=\(flag))")
        if flag {
            if panel?.isVisible == true {
                NSApp.activate(ignoringOtherApps: true)
                panel?.orderFrontRegardless()
            }
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }

    // MARK: - 상태 관찰 (alwaysOnTop / menuBar / dock)

    private func observe(_ store: ConfigStore) {
        store.$alwaysOnTop
            .sink { [weak self] alwaysOnTop in
                guard let panel = self?.panel else { return }
                panel.level = alwaysOnTop ? .floating : .normal
            }
            .store(in: &cancellables)

        store.$showInMenuBar
            .sink { [weak self] showInMenuBar in
                guard let self else { return }
                if showInMenuBar {
                    if self.statusItem == nil { self.setupStatusItem() }
                } else {
                    self.removeStatusItem()
                }
            }
            .store(in: &cancellables)

        store.$showInDock
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, let store = self.store else { return }
                self.applyActivationPolicy(store)
            }
            .store(in: &cancellables)

        store.$showPalette
            .sink { [weak self] show in
                guard let self else { return }
                if show {
                    self.showPalettePanel()
                } else {
                    self.hidePalettePanel()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 실행 취소/다시 실행 (Edit 메뉴 — 텍스트 필드 미처리 시 위임)

    @objc func undo(_ sender: Any?) {
        if let mgr = NSApp.keyWindow?.undoManager, mgr.canUndo {
            mgr.undo()
            return
        }
        Logger.info("AppDelegate", "[UNDO] 실행 취소 가능한 컨텍스트 없음")
    }

    @objc func redo(_ sender: Any?) {
        if let mgr = NSApp.keyWindow?.undoManager, mgr.canRedo {
            mgr.redo()
            return
        }
        Logger.info("AppDelegate", "[REDO] 다시 실행 가능한 컨텍스트 없음")
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // 설정/정보 창은 닫혀도 참조를 유지(숨김) → 다음 열람 시 재사용(makeKeyAndOrderFront).
        // 이렇게 하면 창 dealloc이 발생하지 않아 닫기 애니메이션(_NSWindowTransformAnimation) 크래시와 dangling 참조를 모두 방지.
    }
}
