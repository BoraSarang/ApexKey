import AppKit
import SwiftUI
import Combine

/// 메뉴바 상태 아이템 + 독립 플로팅 창 관리
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var debugWindow: NSWindow?
    private var quickLauncherWindow: NSPanel?
    private var menuHUDWindow: NSPanel?
    private var menuHUDOverlayWindow: NSPanel?
    private var editorWindow: NSWindow?
    private var stepSettingsWindow: NSWindow?
    // NSWindow.contentViewController는 strong(직접 참조 유지)이지만, NSHostingController가
    // 창 dealloc보다 먼저 해제되는 것을 막기 위해 슈퍼타입으로 안전하게 보관해 둔다.
    private var panelHosting: NSViewController?
    private var settingsHosting: NSViewController?
    private var aboutHosting: NSViewController?
    private var debugHosting: NSViewController?
    private var quickLauncherHosting: NSViewController?
    private var menuHUDHosting: NSViewController?
    private var menuHUDOverlayHosting: NSViewController?
    private var editorHosting: NSViewController?
    private var stepSettingsHosting: NSViewController?
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
        let mainMenu = NSMenu()

        let appMenu = NSMenu()
        let appName = "ApexKey"
        let about = NSMenuItem(title: "\(appName) 정보", action: #selector(showAboutPanel(_:)), keyEquivalent: "")
        about.target = self
        let sep1 = NSMenuItem.separator()
        let settings = NSMenuItem(title: "설정…", action: #selector(showSettingsPanel(_:)), keyEquivalent: ",")
        settings.target = self
        let sep2 = NSMenuItem.separator()
        let quit = NSMenuItem(title: "\(appName) 종료", action: #selector(terminateApp(_:)), keyEquivalent: "q")
        quit.target = self
        appMenu.addItem(about)
        appMenu.addItem(sep1)
        appMenu.addItem(settings)
        appMenu.addItem(sep2)
        appMenu.addItem(quit)

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - 툴바/플로팅 창 메뉴 구성 (우클릭 드롭다운)

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "열기", action: #selector(togglePanelAction(_:)), keyEquivalent: "o")
        openItem.target = self
        let infoItem = NSMenuItem(title: "정보", action: #selector(showAboutPanel(_:)), keyEquivalent: "")
        infoItem.target = self
        let settingsItem = NSMenuItem(title: "설정…", action: #selector(showSettingsPanel(_:)), keyEquivalent: ",")
        settingsItem.target = self
        let debugItem = NSMenuItem(title: "디버그 로그", action: #selector(showDebugPanel(_:)), keyEquivalent: "")
        debugItem.target = self
        menu.addItem(openItem)
        menu.addItem(infoItem)
        menu.addItem(settingsItem)
        menu.addItem(debugItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(terminateApp(_:)), keyEquivalent: "q"))
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
        if let screen = NSScreen.main {
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
            win.title = "ApexKey 설정"
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
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 320),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.title = "ApexKey 정보"
            win.styleMask.remove(.resizable)
            win.isReleasedWhenClosed = false
            let hosting = NSHostingController(rootView: ThemedRoot { AboutView() })
            aboutHosting = hosting
            win.contentViewController = hosting
            win.setContentSize(NSSize(width: 380, height: 320))
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
            win.title = "ApexKey 디버그 로그"
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
    func showEditor(for shortcut: ShortcutItem) {
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
            w.title = "동작 편집"
            w.isReleasedWhenClosed = false // 재사용 동안 dealloc 방지
            w.delegate = self
            editorWindow = w
            win = w
        }
        // 편집 대상 단축어가 바뀔 수 있으므로 매번 새 호스팅 컨트롤러로 rootView 교체
        let hosting = NSHostingController(rootView:
            ThemedRoot { ShortcutEditorView(shortcut: shortcut) }.environmentObject(store)
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
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            w.title = "단계 설정"
            w.isReleasedWhenClosed = false
            w.delegate = self
            stepSettingsWindow = w
            win = w
        }
        // 편집 대상 단계가 바뀔 수 있으므로 매번 새 호스팅 컨트롤러로 rootView 교체
        let hosting = NSHostingController(rootView: ThemedRoot { StepSettingsView(step: stepBinding) })
        stepSettingsHosting = hosting
        win.contentViewController = hosting
        win.setContentSize(NSSize(width: 480, height: 560))
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

        store.$showQuickLauncher
            .sink { [weak self] show in
                guard let self else { return }
                if show {
                    self.showQuickLauncherPanel()
                } else {
                    self.hideQuickLauncherPanel()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Quick Launcher

    private func showQuickLauncherPanel() {
        if quickLauncherWindow == nil {
            let win = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            win.title = "Quick Launcher"
            win.isFloatingPanel = true
            win.level = .floating
            win.isMovableByWindowBackground = false
            win.hidesOnDeactivate = false
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            win.hasShadow = true
            win.backgroundColor = .clear
            win.isOpaque = false
            win.styleMask = [.borderless]

            guard let store else { return }
            let hosting = NSHostingController(rootView: ThemedRoot { QuickLauncherView() }.environmentObject(store))
            quickLauncherHosting = hosting
            win.contentViewController = hosting

            if let screen = NSScreen.main {
                let r = screen.visibleFrame
                let x = r.midX - win.frame.width / 2
                let y = r.maxY - win.frame.height - 40
                win.setFrameOrigin(NSPoint(x: x, y: y))
            }

            win.delegate = self
            quickLauncherWindow = win
        }
        guard let win = quickLauncherWindow else { return }
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        win.level = .floating
    }

    private func hideQuickLauncherPanel() {
        quickLauncherWindow?.orderOut(nil)
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

        guard let win = menuHUDOverlayWindow, let screen = NSScreen.main else { return }
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
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let x = visible.midX - 230
        let y = visible.maxY - 420 - 120
        win.setFrame(NSRect(x: x, y: y, width: 460, height: 420), display: true)
        win.layoutIfNeeded()
    }
}

/// 보더리스 플로팅 패널이 키 포커스(ESC 등)를 받도록 key가 될 수 있게 하는 서브클래스
final class KeyCapablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // 설정/정보 창은 닫혀도 참조를 유지(숨김) → 다음 열람 시 재사용(makeKeyAndOrderFront).
        // 이렇게 하면 창 dealloc이 발생하지 않아 닫기 애니메이션(_NSWindowTransformAnimation) 크래시와 dangling 참조를 모두 방지.
    }
}
