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

    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var debugWindow: NSWindow?
    private var paletteWindow: NSPanel?
    private var menuHUDWindow: NSPanel?
    private var menuHUDOverlayWindow: NSPanel?
    private var editorWindow: NSWindow?
    private var stepSettingsWindow: NSWindow?
    private var stepTestResultWindow: NSWindow?
    private var updateWindow: NSWindow?
    // NSWindow.contentViewController는 strong(직접 참조 유지)이지만, NSHostingController가
    // 창 dealloc보다 먼저 해제되는 것을 막기 위해 슈퍼타입으로 안전하게 보관해 둔다.
    private var panelHosting: NSViewController?
    private var settingsHosting: NSViewController?
    private var aboutHosting: NSViewController?
    private var debugHosting: NSViewController?
    private var paletteHosting: NSViewController?
    private var menuHUDHosting: NSViewController?
    private var menuHUDOverlayHosting: NSViewController?
    private var editorHosting: NSViewController?
    private var stepSettingsHosting: NSViewController?
    private var stepTestResultHosting: NSViewController?
    private var updateHosting: NSViewController?
    private var toastHosting: NSViewController?
    private var toastWindow: NSPanel?
    private var toastTimer: Timer?
    private var store: ConfigStore?
    private var cancellables = Set<AnyCancellable>()

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

    // MARK: - 상태 아이템 (showInMenuBar 구동)

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "command.square.fill", accessibilityDescription: "ApexKey")
            image?.isTemplate = true // 메뉴바 단색 템플릿
            button.image = image

            // 좌클릭 → 창 토글, 우클릭 → 메뉴
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
        Logger.info("AppDelegate", "[MENU] 메뉴바 상태 아이템 생성")
    }

    private func removeStatusItem() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        Logger.info("AppDelegate", "[MENU] 메뉴바 상태 아이템 제거")
    }

    // MARK: - Dock 정책 (showInDock 구동)

    private func applyActivationPolicy(_ store: ConfigStore) {
        // .accessory = 메뉴바만(기본), .regular = Dock + 메뉴바
        NSApp.setActivationPolicy(store.showInDock ? .regular : .accessory)
    }

    // MARK: - 시스템 메뉴바 (Dock 표시 시 명령 제공)

    private func setupSystemMenu() {
        NSApp.mainMenu = Self.makeMainMenu(actionTarget: self)
    }

    /// 메뉴 항목 생성 보일러플레이트(NSMenuItem 생성 + target 지정)를 한 곳으로 모음.
    /// target이 nil이면 responder chain을 탄다(편집 메뉴 표준 액션용).
    private static func makeItem(title: String, action: Selector?, key: String, target: AnyObject?) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        return item
    }

    /// 메인 메뉴 구성 — 테스트에서 구조 검증 가능하도록 순수 빌더로 분리.
    /// target을 nil로 두는 편집 항목들은 responder chain을 타서 포커스된 텍스트 뷰가 처리한다.
    static func makeMainMenu(actionTarget: AnyObject?) -> NSMenu {
        let mainMenu = NSMenu()

        let appMenu = NSMenu()
        let appName = "ApexKey"
        let about = makeItem(title: "ui.menu.about".localizedFormat(appName), action: #selector(AppDelegate.showAboutPanel(_:)), key: "", target: actionTarget)
        let sep1 = NSMenuItem.separator()
        let settings = makeItem(title: "ui.main.settings".localized, action: #selector(AppDelegate.showSettingsPanel(_:)), key: ",", target: actionTarget)
        let sep2 = NSMenuItem.separator()
        let quit = makeItem(title: "ui.menu.quit".localizedFormat(appName), action: #selector(AppDelegate.terminateApp(_:)), key: "q", target: actionTarget)
        appMenu.addItem(about)
        appMenu.addItem(sep1)
        appMenu.addItem(settings)
        appMenu.addItem(sep2)
        appMenu.addItem(quit)

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 편집 메뉴 — 없으면 TextEditor/TextField에서 Cmd+C/V/X/A/Z가 동작하지 않음.
        // (AppKit은 메인 메뉴의 표준 edit action을 통해 first responder로 전달)
        let editMenu = NSMenu(title: "ui.edit".localized)
        let editItems: [(String, Selector, String)] = [
            ("ui.menu.undo".localized, Selector("undo:"), "z"),
            ("ui.menu.redo".localized, Selector("redo:"), "Z"),
            ("ui.menu.cut".localized, #selector(NSText.cut(_:)), "x"),
            ("ui.copy".localized, #selector(NSText.copy(_:)), "c"),
            ("ui.menu.paste".localized, #selector(NSText.paste(_:)), "v"),
            ("ui.clear".localized, #selector(NSText.delete(_:)), ""),
            ("ui.menu.select_all".localized, #selector(NSText.selectAll(_:)), "a"),
        ]
        for (index, (title, action, key)) in editItems.enumerated() {
            if index == 2 || index == 6 { editMenu.addItem(.separator()) }
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            // target 미지정 → responder chain (포커스된 텍스트 뷰가 처리)
            editMenu.addItem(item)
        }
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        return mainMenu
    }

    // MARK: - 툴바/플로팅 창 메뉴 구성 (우클릭 드롭다운)

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let openItem = Self.makeItem(title: "ui.open".localized, action: #selector(togglePanelAction(_:)), key: "o", target: self)
        let infoItem = Self.makeItem(title: "ui.info".localized, action: #selector(showAboutPanel(_:)), key: "", target: self)
        let settingsItem = Self.makeItem(title: "ui.main.settings".localized, action: #selector(showSettingsPanel(_:)), key: ",", target: self)
        let updateItem = Self.makeItem(title: "menu.check_update".localized, action: #selector(checkForUpdateAction(_:)), key: "", target: self)
        let debugItem = Self.makeItem(title: "ui.menu.debug_log".localized, action: #selector(showDebugPanel(_:)), key: "", target: self)
        menu.addItem(openItem)
        menu.addItem(infoItem)
        menu.addItem(settingsItem)
        menu.addItem(updateItem)
        menu.addItem(debugItem)
        menu.addItem(.separator())
        menu.addItem(Self.makeItem(title: "ui.quit".localized, action: #selector(terminateApp(_:)), key: "q", target: nil))
        return menu
    }

    // MARK: - 좌/우 클릭 분기

    @objc private func handleClick(_ sender: Any?) {
        guard let button = statusItem?.button, let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            Logger.info("AppDelegate", "[MENU] 우클릭 → 컨텍스트 메뉴")
            // 표준 API로 메뉴바 아래 정상 방향의 컨텍스트 메뉴를 펼친다.
            // (popUp(in: nil)은 화면 좌표 역방향으로 열려 "위로" 중첩이 생기는 문제가 있었음)
            NSMenu.popUpContextMenu(buildMenu(), with: event, for: button)
            return
        }
        Logger.info("AppDelegate", "[MENU] 좌클릭 → 패널 토글")
        togglePanel()
    }

    @objc private func togglePanelAction(_ sender: Any?) {
        togglePanel()
    }

    // MARK: - 메인 플로팅 창

    private func setupPanel(with store: ConfigStore) {
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

    private func togglePanel() {
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

    @objc private func showSettingsPanel(_ sender: Any?) {
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

    @objc private func showAboutPanel(_ sender: Any?) {
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

    @objc private func showDebugPanel(_ sender: Any?) {
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

    @objc private func terminateApp(_ sender: Any?) {
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
    private func placeToast(_ win: NSPanel) {
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
    @objc private func checkForUpdateAction(_ sender: Any?) {
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

    // MARK: - URL Scheme 처리

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleOpenURL(url)
        }
    }

    func handleOpenURL(_ url: URL) {
        guard let store = self.store else { return }
        guard url.scheme == "apexkey" else { return }
        Logger.info("AppDelegate", "[URL] URL 수신: \(url.absoluteString)")

        if url.host == "run-binding",
           let bindingID = UUID(uuidString: url.lastPathComponent) {
            if let binding = store.bindings.first(where: { $0.id == bindingID }) {
                let frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                if ActionExecutor.shared.shouldExecute(binding, frontmostBundleID: frontBundle) {
                    ActionExecutor.shared.execute(binding)
                    Logger.info("AppDelegate", "[URL] binding 실행: \(bindingID)")
                }
            } else {
                Logger.error("E-MAC-URL-4001", "binding을 찾을 수 없음: \(bindingID)")
            }
        } else if url.host == "run-macro-by-name",
                  let name = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "name" })?.value {
            if let binding = store.bindings.first(where: { $0.title == name }) {
                let frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                if ActionExecutor.shared.shouldExecute(binding, frontmostBundleID: frontBundle) {
                    ActionExecutor.shared.execute(binding)
                    Logger.info("AppDelegate", "[URL] 매크로 이름으로 실행: \(name)")
                }
            } else {
                Logger.error("E-MAC-URL-4002", "매크로를 찾을 수 없음: \(name)")
            }
        } else {
            Logger.error("E-MAC-URL-4003", "알 수 없는 URL: \(url.absoluteString)")
        }
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

    // MARK: - 명령 팔레트 (⌘⌥K)

    private func showPalettePanel() {
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

    private func hidePalettePanel() {
        paletteWindow?.orderOut(nil)
    }

    // MARK: - Menu HUD (전면 앱 단축키 표시)

    @objc private func toggleMenuHUD() {
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
    private func showMenuHUDFloating(appName: String, icon: NSImage?, groups: [(menu: String, items: [MenuItem])], bundleID: String, count: Int) {
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
    private func showMenuHUDOverlay(appName: String, icon: NSImage?, groups: [(menu: String, items: [MenuItem])], bundleID: String, count: Int) {
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
    private func runMenuItem(_ item: MenuItem, in bundleID: String) {
        let result = MenuEnumerator.shared.performAction(item, in: bundleID)
        Logger.info("AppDelegate", "[HUD] 항목 실행 \(result.isSuccess ? "성공" : "실패"): \(item.title)")
        hideMenuHUD()
    }

    private func hideMenuHUD() {
        menuHUDWindow?.orderOut(nil)
        menuHUDOverlayWindow?.orderOut(nil)
        Logger.info("AppDelegate", "[HUD] 닫기")
    }

    /// 화면 상단 1/3 지점(중앙)에 고정 크기로 HUD 배치
    private func placeMenuHUD(_ win: NSPanel) {
        guard let screen = Self.screen(for: win) else { return }
        let visible = screen.visibleFrame
        let x = visible.midX - 230
        let y = visible.maxY - 420 - 120
        win.setFrame(NSRect(x: x, y: y, width: 460, height: 420), display: true)
        win.layoutIfNeeded()
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

/// 보더리스 플로팅 패널이 키 포커스(ESC 등)를 받도록 key가 될 수 있게 하는 서브클래스
final class KeyCapablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// 실행 결과 토스트 전용 — 클릭은 받되 key/main이 되지 않아 전면 앱 포커스를 유지한다
final class ToastPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // 설정/정보 창은 닫혀도 참조를 유지(숨김) → 다음 열람 시 재사용(makeKeyAndOrderFront).
        // 이렇게 하면 창 dealloc이 발생하지 않아 닫기 애니메이션(_NSWindowTransformAnimation) 크래시와 dangling 참조를 모두 방지.
    }
}
