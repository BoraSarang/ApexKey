//
//  AppDelegate+Windows.swift
//  ApexKey
//
//  Floating panel, settings/about/debug, editor, toast, update windows
//

import AppKit
import SwiftUI
import Combine

extension AppDelegate {
    // MARK: - 메인 플로팅 창

    func setupPanel(with store: ConfigStore) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 560),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "ApexKey"
        panel.isFloatingPanel = true
        panel.level = store.alwaysOnTop ? .floating : .normal // 기본 항상 위에
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.minSize = NSSize(width: 760, height: 500)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.toolbarStyle = .unified // 통합 툴바 — 타이틀바 공유

        let hosting = NSHostingController(rootView:
            ThemedRoot { MainWindowView() }.environmentObject(store)
        )
        panelHosting = hosting
        panel.contentViewController = hosting

        // contentViewController 설정 시 콘텐츠 fittingSize로 리사이즈될 수 있어,
        // 처음 열리는 크기를 명시적으로 재적용해 사이드바·상세 영역이 부족하지 않게 한다.
        panel.setContentSize(NSSize(width: 900, height: 620))

        // 화면 중앙 첫 배치
        if let screen = Self.screen(for: panel) {
            let r = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(
                x: r.midX - panel.frame.width / 2,
                y: r.midY - panel.frame.height / 2
            ))
        }

        panel.delegate = self
        self.panel = panel
    }

    func togglePanel() {
        guard let panel else { return }
        // 전방에 실제로 보이는(key) 경우에만 닫고, 뒤로 숨었거나(다른 앱에 가려짐) 없으면
        // 앞으로 가져온다. isVisible만 보면 뒤로 숨은 패널을 "닫힘"으로 오판해
        // 첫 클릭이 반응 없음처럼 보이는 문제를 방지한다.
        if panel.isVisible && (panel.isKeyWindow || NSApp.keyWindow === panel) {
            Logger.info("AppDelegate", "[PANEL] 닫기")
            panel.orderOut(nil)
        } else {
            Logger.info("AppDelegate", panel.isVisible ? "[PANEL] 앞으로 가져오기" : "[PANEL] 열기")
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
            // 패널 열 때 주기가 됐으면 조용히 확인 (자동 팝업 없음)
            if let store {
                Task {
                    await store.maybeAutoCheckForUpdate()
                }
            }
        }
    }

    // MARK: - 설정 / 정보 창

    @objc func showSettingsPanel(_ sender: Any?) {
        guard let store else { return }
        Logger.info("AppDelegate", "[SETTINGS] 설정 창 요청")
        // LSUIElement 앱에서는 먼저 활성화해야 SwiftUI 레이아웃이 잡힘 (빈 창 방지)
        NSApp.activate(ignoringOtherApps: true)
        if settingsWindow == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 580, height: 420),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.title = "ui.window.settings".localized
            win.minSize = NSSize(width: 560, height: 400)
            win.isReleasedWhenClosed = false // 재사용되는 동안 dealloc 방지
            let hosting = NSHostingController(rootView:
                ThemedRoot { SettingsView() }.environmentObject(store)
            )
            settingsHosting = hosting
            win.contentViewController = hosting
            // contentViewController 설정 시 윈도우가 컨트롤러 크기로 자동 리사이즈됨.
            // 호스팅 fitting 크기가 어긋나면 빈 창이 되므로 생성 직후 명시적으로 재적용.
            win.setContentSize(NSSize(width: 580, height: 420))
            win.delegate = self
            settingsWindow = win
        }
        if let win = settingsWindow {
            win.level = store.alwaysOnTop ? .floating : .normal
            win.center()
            win.contentView?.layoutSubtreeIfNeeded()
            win.makeKeyAndOrderFront(nil)
        }
    }

    @objc func showAboutPanel(_ sender: Any?) {
        guard let store else { return }
        Logger.info("AppDelegate", "[ABOUT] 정보 창 요청")
        NSApp.activate(ignoringOtherApps: true)
        if aboutWindow == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 360),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.title = "ui.window.about".localized
            win.styleMask.remove(.resizable)
            win.isReleasedWhenClosed = false
            let hosting = NSHostingController(rootView: ThemedRoot { AboutView() }.environmentObject(store))
            aboutHosting = hosting
            win.contentViewController = hosting
            win.setContentSize(NSSize(width: 380, height: 360))
            win.delegate = self
            aboutWindow = win
        }
        if let win = aboutWindow {
            win.level = store.alwaysOnTop ? .floating : .normal
            win.center()
            win.contentView?.layoutSubtreeIfNeeded()
            win.makeKeyAndOrderFront(nil)
        }
    }

    @objc func showDebugPanel(_ sender: Any?) {
        Logger.info("AppDelegate", "[DEBUG] 디버그 로그 창 요청")
        NSApp.activate(ignoringOtherApps: true)
        if debugWindow == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 460),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.title = "ui.window.debug_log".localized
            win.minSize = NSSize(width: 480, height: 300)
            win.isReleasedWhenClosed = false
            let hosting = NSHostingController(rootView: ThemedRoot { DebugLogView() })
            debugHosting = hosting
            win.contentViewController = hosting
            win.setContentSize(NSSize(width: 640, height: 460))
            win.delegate = self
            debugWindow = win
        }
        if let win = debugWindow {
            win.level = store?.alwaysOnTop == true ? .floating : .normal
            win.center()
            win.contentView?.layoutSubtreeIfNeeded()
            win.makeKeyAndOrderFront(nil)
        }
    }

    @objc func terminateApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    // MARK: - 동작(단축어) 편집기 / 단계 설정 독립 창

    /// 동작(단축어) 3컬럼 편집기를 독립 창으로 표시
    func showEditor(for shortcut: ShortcutItem, selectedStepID: UUID? = nil) {
        guard let store else { return }
        Logger.info("AppDelegate", "[EDITOR] 동작 편집 창: \(shortcut.name)")
        NSApp.activate(ignoringOtherApps: true)
        let win: NSWindow
        if let existing = editorWindow {
            win = existing
        } else {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            w.title = "ui.menu.edit_shortcut".localized
            w.isReleasedWhenClosed = false // 재사용 동안 dealloc 방지
            w.delegate = self
            editorWindow = w
            win = w
        }
        // 편집 대상 단축어가 바뀔 수 있으므로 매번 새 호스팅 컨트롤러로 rootView 교체
        let hosting = NSHostingController(rootView:
            ThemedRoot { ShortcutEditorView(shortcut: shortcut, initialSelectedStepID: selectedStepID) }.environmentObject(store)
        )
        editorHosting = hosting
        win.contentViewController = hosting
        win.setContentSize(NSSize(width: 900, height: 600))
        win.level = store.alwaysOnTop ? .floating : .normal
        win.center()
        win.contentView?.layoutSubtreeIfNeeded()
        win.makeKeyAndOrderFront(nil)
    }

    /// 단계 상세 설정을 독립 창으로 표시 — 전달된 Binding이 편집기의 steps 요소를 가리킴
    func showStepSettings(for stepBinding: Binding<ShortcutStep>) {
        Logger.info("AppDelegate", "[EDITOR] 단계 설정 창")
        NSApp.activate(ignoringOtherApps: true)
        let win: NSWindow
        if let existing = stepSettingsWindow {
            win = existing
        } else {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 680),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            w.title = "ui.menu.step_settings".localized
            w.isReleasedWhenClosed = false
            w.delegate = self
            stepSettingsWindow = w
            win = w
        }
        // 편집 대상 단계가 바뀔 수 있으므로 매번 새 호스팅 컨트롤러로 rootView 교체
        let hosting = NSHostingController(rootView: ThemedRoot { StepSettingsView(step: stepBinding) })
        stepSettingsHosting = hosting
        win.contentViewController = hosting
        win.setContentSize(NSSize(width: 480, height: 680))
        win.center()
        win.contentView?.layoutSubtreeIfNeeded()
        win.makeKeyAndOrderFront(nil)
    }

    /// 단계 테스트 상세 결과를 별도 창으로 표시 — 설정 창은 좁게 유지하고
    /// 결과만 넓은 창(리사이즈 가능)에서 확인한다.
    func showStepTestResult(title: String, success: Bool, output: String, errorOutput: String, exitCode: Int32) {
        Logger.info("AppDelegate", "[STEP-TEST] 결과 창 (success=\(success))")
        NSApp.activate(ignoringOtherApps: true)
        let win: NSWindow
        if let existing = stepTestResultWindow {
            win = existing
        } else {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 460),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            w.isReleasedWhenClosed = false
            w.delegate = self
            stepTestResultWindow = w
            win = w
        }
        win.title = "ui.step_settings.test_output".localized + " — " + title
        let hosting = NSHostingController(rootView: ThemedRoot {
            StepTestResultView(stepTitle: title, success: success, output: output, errorOutput: errorOutput, exitCode: exitCode)
        })
        stepTestResultHosting = hosting
        win.contentViewController = hosting
        win.setContentSize(NSSize(width: 600, height: 460))
        win.contentView?.layoutSubtreeIfNeeded()
        win.makeKeyAndOrderFront(nil)
    }

    // MARK: - 실행 결과 토스트 (OS 알림센터 미사용)

    /// 글로벌 단축키 실행 결과를 우상단 플로팅 토스트로 표시.
    /// 포커스를 뺏지 않도록 key 지정·activate 없이 orderFront만 한다.
    /// 성공 1.5초 / 실패 6초 후 자동 닫힘. 실패 탭 시 디버그 로그를 연다.
    func showToast(title: String, message: String? = nil, success: Bool) {
        if success, store?.showSuccessToast == false {
            return
        }
        let payload = ToastPayload(title: title, message: message, success: success)
        let hosting = NSHostingController(rootView: ThemedRoot {
            ToastView(payload: payload) { [weak self] in
                self?.hideToast()
                self?.openDebugLog()
            }
        })
        toastHosting = hosting

        let win: NSPanel
        if let existing = toastWindow {
            win = existing
        } else {
            let w = ToastPanel(
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 110),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            w.isFloatingPanel = true
            w.level = .floating
            w.hidesOnDeactivate = false
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = false
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            w.delegate = self
            toastWindow = w
            win = w
        }
        win.contentViewController = hosting
        win.setContentSize(NSSize(width: 340, height: success ? 60 : 110))
        placeToast(win)
        win.contentView?.layoutSubtreeIfNeeded()
        // key로 만들지 않음 — 전면 앱 포커스 유지
        win.orderFront(nil)

        toastTimer?.invalidate()
        toastTimer = Timer.scheduledTimer(withTimeInterval: success ? 1.5 : 6.0, repeats: false) { [weak self] _ in
            self?.hideToast()
        }
        Logger.info("AppDelegate", "[TOAST] \(success ? "성공" : "실패"): \(title)")
    }

    func hideToast() {
        toastTimer?.invalidate()
        toastTimer = nil
        toastWindow?.orderOut(nil)
    }

    /// 우상단 (메뉴바 아래) 배치
    func placeToast(_ win: NSPanel) {
        guard let screen = Self.screen(for: win) else { return }
        let visible = screen.visibleFrame
        let size = win.frame.size
        win.setFrameOrigin(NSPoint(
            x: visible.maxX - size.width - 16,
            y: visible.maxY - size.height - 16
        ))
    }

    /// 디버그 로그 창 열기 (토스트 탭·메뉴 공용)
    func openDebugLog() {
        showDebugPanel(nil)
    }

    // MARK: - 업데이트 확인·안내 창

    /// 메뉴바 "업데이트 확인…" — 이미 알림 상태면 창만 열고,
    /// 아니면 조회 후 새 버전일 때 자동 팝업.
    @objc func checkForUpdateAction(_ sender: Any?) {
        guard let store else { return }
        if store.availableUpdate != nil {
            showUpdateWindow()
            return
        }
        Task { [weak self] in
            let hasUpdate = await store.checkForUpdate()
            if hasUpdate {
                self?.showUpdateWindow()
            }
        }
    }

    /// 설정 밖에서 여는 업데이트 안내 창 — AppDelegate가 수명주기 소유.
    /// 설정 경로(.sheet)와 공유하되, dismiss 대신 onClose로 윈도우를 직접 닫는다.
    func showUpdateWindow() {
        guard let store, let release = store.availableUpdate else { return }
        Logger.info("AppDelegate", "[UPDATE] 업데이트 안내 창: \(release.tagName)")
        NSApp.activate(ignoringOtherApps: true)
        if updateWindow == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.title = "update.section".localized
            win.isReleasedWhenClosed = false
            win.delegate = self
            updateWindow = win
        }
        guard let win = updateWindow else { return }
        let hosting = NSHostingController(rootView:
            ThemedRoot {
                UpdateAvailableSheet(
                    release: release,
                    currentVersion: ReleaseChecker.currentVersion,
                    onClose: { [weak self] in self?.updateWindow?.close() }
                )
            }.environmentObject(store)
        )
        updateHosting = hosting
        win.contentViewController = hosting
        win.setContentSize(NSSize(width: 480, height: 520))
        win.level = store.alwaysOnTop ? .floating : .normal
        win.center()
        win.contentView?.layoutSubtreeIfNeeded()
        win.makeKeyAndOrderFront(nil)
    }
}
