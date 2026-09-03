import Foundation
import SwiftData
import AppKit
import Combine

/// 앱 전역 상태 저장소 (SwiftData + HotKeyService 연동)
@MainActor
final class ConfigStore: ObservableObject {
    @Published var apps: [AppItem] = []
    @Published var bindings: [HotKeyBinding] = []
    @Published var scripts: [ScriptItem] = []
    @Published var showHiddenApps = false
    @Published var showQuickLauncher = false
    @Published var menuHUDHotkey: HotKeyCombo
    @Published var toggleHotkey: HotKeyCombo
    @Published var alwaysOnTop = false {
        didSet { UserDefaults.standard.set(alwaysOnTop, forKey: PrefKeys.alwaysOnTop) }
    }
    @Published var showInMenuBar = true {
        didSet { UserDefaults.standard.set(showInMenuBar, forKey: PrefKeys.showInMenuBar) }
    }
    @Published var showInDock = false {
        didSet { UserDefaults.standard.set(showInDock, forKey: PrefKeys.showInDock) }
    }
    @Published var menuHUDStyle: MenuHUDStyle = .floatingWindow {
        didSet { UserDefaults.standard.set(menuHUDStyle.rawValue, forKey: PrefKeys.menuHUDStyle) }
    }
    @Published var showNoShortcutItems: Bool = true {
        didSet { UserDefaults.standard.set(showNoShortcutItems, forKey: PrefKeys.showNoShortcutItems) }
    }

    private var container: ModelContainer?
    private var cancellables = Set<AnyCancellable>()

    private let hotKeyService = HotKeyService.shared
    private let actionExecutor = ActionExecutor.shared

    /// ⇧⌥A 패널 토글 핫키 전용 등록 ID (bindings 배열 밖의 예약 ID)
    private let panelToggleID = UUID()

    /// ⌘⇧↩ 마지막 바인딩 반복 전용 등록 ID
    private let repeatLastID = UUID()

    /// ⌥⌘Space Quick Launcher 전용 등록 ID
    private let quickLauncherID = UUID()

    /// ⇧⌥S Menu HUD 전용 등록 ID (전면 앱 단축키 표시)
    private let menuHUDID = UUID()

    /// 마지막으로 실행된 바인딩 ID (반복용)
    private var lastExecutedBindingID: UUID?

    static let defaultToggleHotkey = HotKeyCombo(
        keyCode: 0, // A
        modifiers: KeyboardUtil.shiftMask | KeyboardUtil.optionMask,
        displayString: "⇧⌥A"
    )

    static let defaultRepeatHotkey = HotKeyCombo(
        keyCode: 36, // Return
        modifiers: KeyboardUtil.cmdMask | KeyboardUtil.shiftMask,
        displayString: "⌘⇧↩"
    )

    static let defaultQuickLauncherHotkey = HotKeyCombo(
        keyCode: 49, // Space
        modifiers: KeyboardUtil.optionMask | KeyboardUtil.cmdMask,
        displayString: "⌥⌘Space"
    )

    static let defaultMenuHUDHotkey = HotKeyCombo(
        keyCode: 1, // S
        modifiers: KeyboardUtil.shiftMask | KeyboardUtil.optionMask,
        displayString: "⇧⌥S"
    )

    /// Menu HUD 표시 방식
    enum MenuHUDStyle: String, CaseIterable, Identifiable {
        case floatingWindow = "floatingWindow"
        case fullscreen = "fullscreen"
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .floatingWindow: return "플로팅 창"
            case .fullscreen: return "전체 보기"
            }
        }
    }

    private enum PrefKeys {
        static let alwaysOnTop = "pref.alwaysOnTop"
        static let showInMenuBar = "pref.showInMenuBar"
        static let showInDock = "pref.showInDock"
        static let menuHUDStyle = "pref.menuHUDStyle"
        static let showNoShortcutItems = "pref.showNoShortcutItems"
    }

    init() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: PrefKeys.showInMenuBar), defaults.object(forKey: PrefKeys.showInMenuBar) == nil {
            defaults.set(true, forKey: PrefKeys.showInMenuBar)
        }
        if !defaults.bool(forKey: PrefKeys.showInDock), defaults.object(forKey: PrefKeys.showInDock) == nil {
            defaults.set(false, forKey: PrefKeys.showInDock)
        }
        // 항상 위에: 기본 Off로 초기화 (기존 저장값 무시 → 강제 리셋)
        defaults.removeObject(forKey: PrefKeys.alwaysOnTop)
        self.alwaysOnTop = false
        self.showInMenuBar = defaults.bool(forKey: PrefKeys.showInMenuBar)
        self.showInDock = defaults.bool(forKey: PrefKeys.showInDock)
        // 이전 표시 문자열("전체 화면 (KeyCue)" 등) → 새 식별자 마이그레이션
        if let raw = defaults.string(forKey: PrefKeys.menuHUDStyle) {
            let legacy: [String: MenuHUDStyle] = [
                "플로팅 창": .floatingWindow,
                "전체 화면 (KeyCue)": .fullscreen,
            ]
            let style = MenuHUDStyle(rawValue: raw) ?? legacy[raw] ?? .floatingWindow
            self.menuHUDStyle = style
            defaults.set(style.rawValue, forKey: PrefKeys.menuHUDStyle)
        }
        self.toggleHotkey = Self.defaultToggleHotkey
        self.menuHUDHotkey = Self.defaultMenuHUDHotkey
        self.showNoShortcutItems = defaults.object(forKey: PrefKeys.showNoShortcutItems) == nil ? true : defaults.bool(forKey: PrefKeys.showNoShortcutItems)
        // 전용 저장소 경로 사용 — 기본 경로(~ibrary/Application Support/default.store)는
        // 다른 SwiftData 앱과 공유되어 스키마 충돌로 컨테이너 생성이 실패할 수 있음
        let schema = Schema([PersistedApp.self, PersistedBinding.self, PersistedScript.self])
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let storeDirectory = appSupport.appendingPathComponent("com.borasarang.ApexKey", isDirectory: true)
        let storeURL = storeDirectory.appendingPathComponent("default.store")
        do {
            try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
            container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: storeURL)]
            )
            load()
        } catch {
            Logger.error("E-MAC-STORE-5001", "ModelContainer 생성 실패 (\(storeURL.path)): \(error.localizedDescription)")
        }

        // 글로벌 핫키 눌림 처리
        hotKeyService.hotKeyPressed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bindingID in
                guard let self else { return }
                if bindingID == self.panelToggleID {
                    // ⇧⌥A → 메인 패널 토글
                    Logger.info("ConfigStore", "[HOTKEY] 패널 토글 핫키 감지: \(self.toggleHotkey.displayString)")
                    NotificationCenter.default.post(name: .togglePanel, object: nil)
                    return
                }
                 if bindingID == self.repeatLastID {
                    // ⌘⇧↩ → 마지막 바인딩 반복
                    self.repeatLastBinding()
                    return
                }
                if bindingID == self.quickLauncherID {
                    // ⌥⌘Space → Quick Launcher 토글
                    self.showQuickLauncher.toggle()
                    Logger.info("ConfigStore", "[HOTKEY] Quick Launcher 토글")
                    return
                }
                if bindingID == self.menuHUDID {
                    // ⇧⌥S → Menu HUD 토글
                    Logger.info("ConfigStore", "[HOTKEY] Menu HUD 토글")
                    NotificationCenter.default.post(name: .toggleMenuHUD, object: nil)
                    return
                }
                self.handleHotKey(bindingID)
            }
            .store(in: &cancellables)

        // 등록된 핫키를 서비스에 반영
        registerAllBindings()
        // ⇧⌥A 패널 토글 핫키 등록
        _ = hotKeyService.register(panelToggleID, combo: toggleHotkey)
        Logger.info("ConfigStore", "[HOTKEY] 패널 토글 핫키 등록: \(toggleHotkey.displayString)")
        // ⌘⇧↩ 마지막 바인딩 반복 핫키 등록
        _ = hotKeyService.register(repeatLastID, combo: Self.defaultRepeatHotkey)
        Logger.info("ConfigStore", "[HOTKEY] 반복 핫키 등록: ⌘⇧↩")
        // ⌥⌘Space Quick Launcher 핫키 등록
        _ = hotKeyService.register(quickLauncherID, combo: Self.defaultQuickLauncherHotkey)
        Logger.info("ConfigStore", "[HOTKEY] Quick Launcher 핫키 등록: ⌥⌘Space")
        // ⇧⌥S Menu HUD 핫키 등록
        _ = hotKeyService.register(menuHUDID, combo: menuHUDHotkey)
        Logger.info("ConfigStore", "[HOTKEY] Menu HUD 핫키 등록: \(menuHUDHotkey.displayString)")
    }

    func load() {
        guard let context = container?.mainContext else { return }
        let appFetch = FetchDescriptor<PersistedApp>()
        let bindingFetch = FetchDescriptor<PersistedBinding>()
        if let persistedApps = try? context.fetch(appFetch) {
            apps = persistedApps.map { $0.toAppItem() }
        }
        if let persistedBindings = try? context.fetch(bindingFetch) {
            bindings = persistedBindings.map { $0.toBinding() }
        }
        let scriptFetch = FetchDescriptor<PersistedScript>()
        if let persistedScripts = try? context.fetch(scriptFetch) {
            scripts = persistedScripts.map { $0.toScript() }
        }
        if apps.isEmpty {
            // 첫 실행 시 설치된 앱 자동 로드
            let installed = AppFinder.installedApps()
            installed.forEach { context.insert(PersistedApp.from($0)) }
            if (try? context.save()) != nil {
                apps = installed
            }
        }
    }

    // MARK: - 앱 관리

    func addApp(_ app: AppItem) {
        guard let context = container?.mainContext else { return }
        context.insert(PersistedApp.from(app))
        try? context.save()
        apps.append(app)
    }

    func addAppsFromInstalled() {
        let installed = AppFinder.installedApps()
        let existingIDs = Set(apps.map { $0.bundleID })
        let new = installed.filter { !existingIDs.contains($0.bundleID) }
        guard let context = container?.mainContext else { return }
        new.forEach { context.insert(PersistedApp.from($0)) }
        try? context.save()
        apps.append(contentsOf: new)
    }

    func toggleHidden(_ app: AppItem) {
        guard let idx = apps.firstIndex(where: { $0.id == app.id }) else { return }
        let updated = AppItem(
            id: app.id, name: app.name, bundleID: app.bundleID, path: app.path,
            category: app.category, isHidden: !app.isHidden
        )
        apps[idx] = updated
        syncApp(updated)
    }

    func removeApp(_ app: AppItem) {
        apps.removeAll { $0.id == app.id }
        guard let context = container?.mainContext else { return }
        let fetch = FetchDescriptor<PersistedApp>(predicate: #Predicate { $0.id == app.id })
        if let found = try? context.fetch(fetch).first {
            context.delete(found)
        }
        try? context.save()
    }

    private func syncApp(_ app: AppItem) {
        guard let context = container?.mainContext else { return }
        let fetch = FetchDescriptor<PersistedApp>(predicate: #Predicate { $0.id == app.id })
        if let found = try? context.fetch(fetch).first {
            found.name = app.name
            found.isHidden = app.isHidden
            found.categoryRaw = app.category.rawValue
            found.path = app.path
        }
        try? context.save()
    }

    func visibleApps() -> [AppItem] {
        if showHiddenApps {
            return apps
        }
        return apps.filter { !$0.isHidden }
    }

    func categoryOrder() -> [AppCategory] {
        AppCategory.allCases
    }

    /// 카테고리별 그룹핑된 파생 뷰 모델
    func appsByCategory() -> [(category: AppCategory, apps: [AppItem])] {
        categoryOrder().compactMap { cat in
            let list = visibleApps().filter { $0.category == cat }
            return list.isEmpty ? nil : (cat, list)
        }
    }

    // MARK: - 스크립트 관리

    func addScript(name: String, command: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cmd = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !cmd.isEmpty else { return }
        let script = ScriptItem(name: trimmed, command: cmd)
        guard let context = container?.mainContext else { return }
        context.insert(PersistedScript.from(script))
        try? context.save()
        scripts.append(script)
    }

    func removeScript(_ script: ScriptItem) {
        scripts.removeAll { $0.id == script.id }
        // 연결된 단축키도 제거
        bindings.filter { $0.actionType == .script && $0.title == script.name }
            .forEach { removeBinding($0) }
        guard let context = container?.mainContext else { return }
        let fetch = FetchDescriptor<PersistedScript>(predicate: #Predicate { $0.id == script.id })
        if let found = try? context.fetch(fetch).first {
            context.delete(found)
        }
        try? context.save()
    }

    /// 스크립트 실행용 바인딩 (launchApp/메뉴처럼 script 종류 조회)
    func scriptBindings(for scriptID: UUID) -> [HotKeyBinding] {
        guard let script = scripts.first(where: { $0.id == scriptID }) else { return [] }
        return bindings.filter { $0.actionType == .script && $0.title == script.name }
    }

    /// 새 액션 타입 바인딩 (paste, wait, coordinateClick, pauseUntilInput)
    var otherBindings: [HotKeyBinding] {
        bindings.filter {
            [ActionType.paste, .wait, .coordinateClick, .pauseUntilInput, .macro].contains($0.actionType)
        }
    }

    // MARK: - 시스템 액션 바인딩

    func systemBindings(for type: SystemActionType) -> [HotKeyBinding] {
        bindings.filter { $0.actionType == .system && $0.target == type.rawValue }
    }

    /// 시스템 액션 단축키 추가/교체 (이미 있으면 첫 항목만 갱신)
    func setSystemBinding(for type: SystemActionType, combo: HotKeyCombo) {
        guard !combo.isEmpty else { return }
        let existing = systemBindings(for: type)
        if let first = existing.first {
            let updated = HotKeyBinding(
                id: first.id,
                combo: combo,
                actionType: .system,
                target: type.rawValue,
                title: "",
                onlyWhenAppActive: false
            )
            removeBinding(first)
            addBinding(updated)
        } else {
            addBinding(HotKeyBinding(
                combo: combo,
                actionType: .system,
                target: type.rawValue,
                title: "",
                onlyWhenAppActive: false
            ))
        }
    }

    // MARK: - 바인딩 관리

    func bindings(for appID: UUID) -> [HotKeyBinding] {
        // launchApp bindings 중 해당 앱 것을 반환 (target == bundleID)
        guard let app = apps.first(where: { $0.id == appID }) else { return [] }
        return bindings.filter { $0.target == app.bundleID }
    }

    /// 특정 앱의 "앱 실행/토글" 단축키 (launchApp 타입)
    func launchBindings(for appID: UUID) -> [HotKeyBinding] {
        guard let app = apps.first(where: { $0.id == appID }) else { return [] }
        return bindings.filter { $0.actionType == .launchApp && $0.target == app.bundleID }
    }

    /// 앱 실행/토글 단축키 추가/교체 (이미 있으면 첫 항목만 갱신)
    func setLaunchBinding(for appID: UUID, combo: HotKeyCombo) {
        guard !combo.isEmpty else { return }
        guard let app = apps.first(where: { $0.id == appID }) else { return }
        if let first = launchBindings(for: appID).first {
            let updated = HotKeyBinding(
                id: first.id,
                combo: combo,
                actionType: .launchApp,
                target: app.bundleID,
                title: app.name,
                onlyWhenAppActive: false
            )
            removeBinding(first)
            addBinding(updated)
        } else {
            addBinding(HotKeyBinding(
                combo: combo,
                actionType: .launchApp,
                target: app.bundleID,
                title: app.name,
                onlyWhenAppActive: false
            ))
        }
    }

    func addBinding(_ binding: HotKeyBinding) {
        // 중복 조합 체크
        if isDuplicate(combo: binding.combo, excluding: binding.id) {
            Logger.info("ConfigStore", "중복 단축키 무시: \(binding.combo.displayString)")
            return
        }
        guard let context = container?.mainContext else { return }
        context.insert(PersistedBinding.from(binding))
        try? context.save()
        bindings.append(binding)
        _ = hotKeyService.register(binding.id, combo: binding.combo)
    }

    func removeBinding(_ binding: HotKeyBinding) {
        bindings.removeAll { $0.id == binding.id }
        hotKeyService.unregister(binding.id)
        guard let context = container?.mainContext else { return }
        let fetch = FetchDescriptor<PersistedBinding>(predicate: #Predicate { $0.id == binding.id })
        if let found = try? context.fetch(fetch).first {
            context.delete(found)
        }
        try? context.save()
    }

    /// 단축키 중복 감지 (다른 binding과 충돌)
    func isDuplicate(combo: HotKeyCombo, excluding id: UUID) -> Bool {
        guard !combo.isEmpty else { return false }
        return bindings.contains { $0.id != id && $0.combo == combo }
    }

    /// ⇧⌥A 패널 토글 핫키 변경 (재등록)
    func setPanelToggleHotkey(_ combo: HotKeyCombo) {
        guard !combo.isEmpty else { return }
        toggleHotkey = combo
        _ = hotKeyService.register(panelToggleID, combo: combo)
        Logger.info("ConfigStore", "[HOTKEY] 패널 토글 핫키 변경: \(combo.displayString)")
    }

    /// ⇧⌥S Menu HUD 핫키 변경 (재등록)
    func setMenuHUDHotkey(_ combo: HotKeyCombo) {
        guard !combo.isEmpty else { return }
        menuHUDHotkey = combo
        _ = hotKeyService.register(menuHUDID, combo: combo)
        Logger.info("ConfigStore", "[HOTKEY] Menu HUD 핫키 변경: \(combo.displayString)")
    }

    /// Menu HUD 표시 방식 전환
    func setMenuHUDStyle(_ style: MenuHUDStyle) {
        menuHUDStyle = style
        Logger.info("ConfigStore", "[HUD] 표시 방식 변경: \(style.rawValue)")
    }

    /// 메뉴바 표시를 전환. Dock도 꺼져 있으면 접근 불가가 되므로 거부하고 false 반환.
    /// - Returns: 적용되면 true, 경고로 거부되면 false
    func setMenuBarVisible(_ visible: Bool) -> Bool {
        if !visible && !showInDock {
            return false
        }
        showInMenuBar = visible
        return true
    }

    /// Dock 표시 전환. (Dock이 켜지면 접근 경로가 생기므로 항상 허용)
    func setDockVisible(_ visible: Bool) {
        showInDock = visible
    }

    private func registerAllBindings() {
        bindings.forEach { _ = hotKeyService.register($0.id, combo: $0.combo) }
    }

    private func handleHotKey(_ bindingID: UUID) {
        guard let binding = bindings.first(where: { $0.id == bindingID }) else {
            Logger.info("ConfigStore", "[HOTKEY] 미등록 binding 감지: \(bindingID.uuidString)")
            return
        }
        lastExecutedBindingID = bindingID
        let frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        Logger.info("ConfigStore", "[HOTKEY] 핫키 감지: \(binding.combo.displayString) (\(binding.actionType.displayName))")
        if actionExecutor.shouldExecute(binding, frontmostBundleID: frontBundle) {
            actionExecutor.execute(binding)
        } else {
            Logger.info("ConfigStore", "[HOTKEY] 실행 조건 미충족: activeApp=\(frontBundle ?? "nil")")
        }
    }

    /// 마지막으로 실행된 바인딩을 반복 실행 (⌘⇧↩)
    func repeatLastBinding() {
        guard let lastID = lastExecutedBindingID else {
            Logger.info("ConfigStore", "[REPEAT] 실행된 바인딩 없음")
            return
        }
        guard let binding = bindings.first(where: { $0.id == lastID }) else {
            Logger.info("ConfigStore", "[REPEAT] 바인딩을 찾을 수 없음: \(lastID.uuidString)")
            return
        }
        let frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if actionExecutor.shouldExecute(binding, frontmostBundleID: frontBundle) {
            actionExecutor.execute(binding)
            Logger.info("ConfigStore", "[REPEAT] 반복 실행: \(binding.combo.displayString)")
        } else {
            Logger.info("ConfigStore", "[REPEAT] 반복 실행 조건 미충합")
        }
    }

    /// Quick Launcher에서 바인딩 실행
    func executeBinding(_ binding: HotKeyBinding) {
        let frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if actionExecutor.shouldExecute(binding, frontmostBundleID: frontBundle) {
            actionExecutor.execute(binding)
            Logger.info("ConfigStore", "[QuickLauncher] 실행: \(binding.title)")
        }
        showQuickLauncher = false
    }

    /// 이름으로 바인딩 검색 (부분 매칭)
    func binding(matching query: String) -> [HotKeyBinding] {
        let q = query.lowercased()
        return bindings.filter {
            $0.title.lowercased().contains(q)
                || $0.actionType.displayName.lowercased().contains(q)
                || $0.combo.displayString.lowercased().contains(q)
        }.sorted { $0.title < $1.title }
    }

    /// 바인딩 복제
    func duplicate(_ binding: HotKeyBinding) {
        let newBinding = HotKeyBinding(
            id: UUID(),
            combo: binding.combo,
            actionType: binding.actionType,
            target: binding.target,
            title: "\(binding.title) (복제)",
            onlyWhenAppActive: binding.onlyWhenAppActive
        )
        addBinding(newBinding)
        Logger.info("ConfigStore", "바인딩 복제: \(binding.title) → \(newBinding.title)")
    }

    /// 바인딩 JSON 내보내기
    func exportBindings() -> Data? {
        try? JSONEncoder().encode(bindings)
    }

    /// 바인딩 JSON 가져오기
    func importBindings(from data: Data) -> Int {
        guard let imported = try? JSONDecoder().decode([HotKeyBinding].self, from: data) else {
            Logger.error("E-MAC-IMPORT-5001", "잘못된 JSON 형식")
            return 0
        }
        var count = 0
        for binding in imported {
            if !isDuplicate(combo: binding.combo, excluding: UUID()) {
                addBinding(binding)
                count += 1
            }
        }
        Logger.info("ConfigStore", "바인딩 가져오기 완료: \(count)개")
        return count
    }

    /// 바인딩 순서 이동 (위/아래)
    func moveBinding(_ binding: HotKeyBinding, direction: MoveDirection) {
        guard let idx = bindings.firstIndex(where: { $0.id == binding.id }) else { return }
        let targetIdx: Int
        switch direction {
        case .up: targetIdx = idx - 1
        case .down: targetIdx = idx + 1
        }
        guard targetIdx >= 0, targetIdx < bindings.count else { return }
        bindings.swapAt(idx, targetIdx)
        Logger.info("ConfigStore", "바인딩 순서 이동: \(binding.title)")
    }
    /// 매크로 녹화 상태
    @Published var isMacroRecording = false
    @Published var macroRecordedKeyCodes: [UInt32] = []

    /// 매크로 녹화 시작
    func startMacroRecording() {
        MacroRecorder.shared.startRecording()
        isMacroRecording = true
        macroRecordedKeyCodes = []
    }

    /// 매크로 녹화 중지 및 새 바인딩 생성
    func stopMacroRecording() -> HotKeyBinding? {
        let keyCodes = MacroRecorder.shared.recordedKeyCodes
        MacroRecorder.shared.stopRecording()
        isMacroRecording = false
        macroRecordedKeyCodes = []

        guard !keyCodes.isEmpty else { return nil }
        let target = keyCodes.map { String($0) }.joined(separator: ",")
        let binding = HotKeyBinding(
            combo: HotKeyCombo(keyCode: keyCodes.first ?? 0, modifiers: 0),
            actionType: .macro,
            target: target,
            title: "매크로 (\(keyCodes.count)키)",
            onlyWhenAppActive: false
        )
        addBinding(binding)
        Logger.info("ConfigStore", "매크록 바인딩 추가: \(binding.title)")
        return binding
    }
}

enum MoveDirection {
    case up
    case down
}
