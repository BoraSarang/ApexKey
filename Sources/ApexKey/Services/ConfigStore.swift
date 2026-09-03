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
    @Published var shortcuts: [ShortcutItem] = []
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
    @Published var showSystemApps: Bool = true {
        didSet {
            UserDefaults.standard.set(showSystemApps, forKey: PrefKeys.showSystemApps)
            if showSystemApps {
                addSystemAppsIfMissing()
            }
        }
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
        static let showSystemApps = "pref.showSystemApps"
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
        self.showSystemApps = defaults.object(forKey: PrefKeys.showSystemApps) == nil ? true : defaults.bool(forKey: PrefKeys.showSystemApps)
        // 전용 저장소 경로 사용 — 기본 경로(~ibrary/Application Support/default.store)는
        // 다른 SwiftData 앱과 공유되어 스키마 충돌로 컨테이너 생성이 실패할 수 있음
        let schema = Schema([PersistedApp.self, PersistedBinding.self, PersistedScript.self, PersistedShortcut.self])
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
            // 기존 카테고리 체계(구 6개) → 신규 표준 체계 자동 이관 (수동 변경 앱 제외, 저장 반영)
            var migrated = false
            for p in persistedApps where !(p.categoryManuallySet ?? false) {
                let migratedCategory = AppCategory.migrate(p.categoryRaw)
                if migratedCategory.rawValue != p.categoryRaw {
                    p.categoryRaw = migratedCategory.rawValue
                    migrated = true
                }
            }
            if migrated { try? context.save() }
        }
        if let persistedBindings = try? context.fetch(bindingFetch) {
            bindings = persistedBindings.map { $0.toBinding() }
        }
        let scriptFetch = FetchDescriptor<PersistedScript>()
        if let persistedScripts = try? context.fetch(scriptFetch) {
            scripts = persistedScripts.map { $0.toScript() }
        }
        let shortcutFetch = FetchDescriptor<PersistedShortcut>()
        if let persistedShortcuts = try? context.fetch(shortcutFetch) {
            shortcuts = persistedShortcuts.map { $0.toShortcut() }
            // 첫 실행(저장 아무것도 없음)이면 예시 단축어 3개 생성 (마이그레이션 아님)
            if shortcuts.isEmpty {
                seedSampleShortcuts(context: context)
            }
        }
        if apps.isEmpty {
            // 첫 실행 시 설치된 앱 자동 로드
            let installed = AppFinder.installedApps()
            installed.forEach { context.insert(PersistedApp.from($0)) }
            if (try? context.save()) != nil {
                apps = installed
            }
        }
        pruneRemovedApps()
        if showSystemApps {
            addSystemAppsIfMissing()
        }
    }

    /// 디스크에서 지워진 앱을 목록·저장에서 자동 정리 (경로가 비어있지 않은데 파일이 없으면 제거)
    private func pruneRemovedApps() {
        let nonexistent = apps.filter {
            !$0.path.isEmpty && !FileManager.default.fileExists(atPath: $0.path)
        }
        guard !nonexistent.isEmpty else { return }
        nonexistent.forEach { removeApp($0) }
        Logger.info("ConfigStore", "[APPS] 디스크에서 사라진 앱 \(nonexistent.count)개 자동 제거")
    }

    // MARK: - 앱 관리

    func addApp(_ app: AppItem) {
        guard let context = container?.mainContext else { return }
        context.insert(PersistedApp.from(app))
        try? context.save()
        apps.append(app)
    }

    func addAppsFromInstalled() {
        let installed = AppFinder.installedApps(includesSystem: showSystemApps)
        let existingIDs = Set(apps.map { $0.bundleID })
        let new = installed.filter { !existingIDs.contains($0.bundleID) }
        guard let context = container?.mainContext else { return }
        new.forEach { context.insert(PersistedApp.from($0)) }
        try? context.save()
        apps.append(contentsOf: new)
    }

    /// 시스템 앱(`/System/`)이 저장 목록에 없으면 스캔해 추가 — 시스템 앱 표시 토글을 켤 때 호출
    private func addSystemAppsIfMissing() {
        let installed = AppFinder.installedApps(includesSystem: true)
            .filter { $0.path.hasPrefix("/System/") }
        let existingIDs = Set(apps.map { $0.bundleID })
        let new = installed.filter { !existingIDs.contains($0.bundleID) }
        guard !new.isEmpty, let context = container?.mainContext else { return }
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
        var result: [AppItem]
        if showHiddenApps {
            result = apps
        } else {
            result = apps.filter { !$0.isHidden }
        }
        if !showSystemApps {
            result = result.filter { !$0.path.hasPrefix("/System/") }
        }
        return result
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

    /// 사용자가 카테고리를 직접 변경 (수동 플래그를 세워 재분류 시 보존)
    func updateCategory(for appID: UUID, to category: AppCategory) {
        guard let idx = apps.firstIndex(where: { $0.id == appID }) else { return }
        apps[idx].category = category
        apps[idx].categoryManuallySet = true
        guard let context = container?.mainContext else { return }
        let fetch = FetchDescriptor<PersistedApp>()
        guard let list = try? context.fetch(fetch),
              let persisted = list.first(where: { $0.id == appID }) else { return }
        persisted.categoryRaw = category.rawValue
        persisted.categoryManuallySet = true
        try? context.save()
        Logger.info("ConfigStore", "[APPS] 카테고리 수동 변경: \(persisted.name) → \(category.rawValue)")
    }

    /// 수동으로 바꾼 앱을 제외한 나머지를 앱 메타데이터로 재분류
    func reclassifyCategories() {
        guard let context = container?.mainContext else { return }
        var changed = false
        for i in apps.indices where !apps[i].categoryManuallySet {
            let category = AppFinder.categorize(path: apps[i].path)
            if category != apps[i].category {
                apps[i].category = category
                changed = true
            }
        }
        guard changed else {
            Logger.info("ConfigStore", "[APPS] 재분류: 변경된 앱 없음")
            return
        }
        let fetch = FetchDescriptor<PersistedApp>()
        guard let persistedList = try? context.fetch(fetch) else { return }
        for persisted in persistedList where !(persisted.categoryManuallySet ?? false) {
            if let app = apps.first(where: { $0.id == persisted.id }) {
                persisted.categoryRaw = app.category.rawValue
            }
        }
        try? context.save()
        Logger.info("ConfigStore", "[APPS] 카테고리 재분류 완료")
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

    // MARK: - 동작(단축어) 관리

    /// 첫 실행 시 예시 단축어 3개 생성 (사용자 학습용)
    private func seedSampleShortcuts(context: ModelContext) {
        let samples: [ShortcutItem] = [
            ShortcutItem(
                name: "작업 시작",
                steps: [
                    ShortcutStep(type: .launchApp, target: "com.apple.Safari", title: "Safari"),
                    ShortcutStep(type: .wait, target: "1.0", title: "대기 1초"),
                    ShortcutStep(type: .launchApp, target: "com.apple.finder", title: "Finder"),
                ]
            ),
            ShortcutItem(
                name: "볼륨 처리",
                steps: [
                    ShortcutStep(type: .macro, target: "49", title: "스페이스"),
                    ShortcutStep(type: .system, target: SystemActionType.mute.rawValue, title: "음소거 토글"),
                ]
            ),
            ShortcutItem(
                name: "정리 시작",
                steps: [
                    ShortcutStep(type: .script, target: "rm -rf ~/Library/Caches/ApexKey-tmp 2>/dev/null; echo 정리 완료", title: "캐시 정리"),
                    ShortcutStep(type: .wait, target: "2.0", title: "대기 2초"),
                    ShortcutStep(type: .system, target: SystemActionType.displaySleep.rawValue, title: "디스플레이 끄기"),
                ]
            ),
        ]
        samples.forEach { context.insert(PersistedShortcut.from($0)) }
        try? context.save()
        shortcuts = samples
        Logger.info("ConfigStore", "[SHORTCUT] 예시 단축어 3개 생성")
    }

    /// 새 동작 생성 (빈 단계)
    @discardableResult
    func addShortcut(name: String) -> ShortcutItem? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let shortcut = ShortcutItem(name: trimmed)
        guard let context = container?.mainContext else { return nil }
        context.insert(PersistedShortcut.from(shortcut))
        try? context.save()
        shortcuts.append(shortcut)
        Logger.info("ConfigStore", "[SHORTCUT] 동작 생성: \(trimmed)")
        return shortcut
    }

    func removeShortcut(_ shortcut: ShortcutItem) {
        if !shortcut.combo.isEmpty {
            hotKeyService.unregister(shortcut.id)
        }
        shortcuts.removeAll { $0.id == shortcut.id }
        guard let context = container?.mainContext else { return }
        let fetch = FetchDescriptor<PersistedShortcut>(predicate: #Predicate { $0.id == shortcut.id })
        if let found = try? context.fetch(fetch).first {
            context.delete(found)
        }
        try? context.save()
        Logger.info("ConfigStore", "[SHORTCUT] 동작 삭제: \(shortcut.name)")
    }

    /// 동작 이름 변경
    func renameShortcut(_ shortcut: ShortcutItem, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = shortcuts.firstIndex(where: { $0.id == shortcut.id }) else { return }
        shortcuts[idx].name = trimmed
        syncShortcut(shortcuts[idx])
    }

    /// 동작에 단계 추가
    func addStep(to shortcut: ShortcutItem, step: ShortcutStep) {
        guard let idx = shortcuts.firstIndex(where: { $0.id == shortcut.id }) else { return }
        shortcuts[idx].steps.append(step)
        syncShortcut(shortcuts[idx])
        Logger.info("ConfigStore", "[SHORTCUT] 단계 추가: \(step.type.displayName)")
    }

    /// 단계 삭제
    func removeStep(from shortcut: ShortcutItem, at index: Int) {
        guard let idx = shortcuts.firstIndex(where: { $0.id == shortcut.id }),
              shortcuts[idx].steps.indices.contains(index) else { return }
        shortcuts[idx].steps.remove(at: index)
        syncShortcut(shortcuts[idx])
    }

    /// 단계 순서 이동 (위/아래)
    func moveStep(in shortcut: ShortcutItem, from index: Int, direction: MoveDirection) {
        guard let idx = shortcuts.firstIndex(where: { $0.id == shortcut.id }),
              shortcuts[idx].steps.indices.contains(index) else { return }
        let targetIdx: Int
        switch direction {
        case .up: targetIdx = index - 1
        case .down: targetIdx = index + 1
        }
        guard targetIdx >= 0, targetIdx < shortcuts[idx].steps.count else { return }
        shortcuts[idx].steps.swapAt(index, targetIdx)
        syncShortcut(shortcuts[idx])
    }

    /// 단계 복제
    func duplicateStep(in shortcut: ShortcutItem, at index: Int) {
        guard let idx = shortcuts.firstIndex(where: { $0.id == shortcut.id }),
              shortcuts[idx].steps.indices.contains(index) else { return }
        let step = shortcuts[idx].steps[index]
        var copy = step
        copy.id = UUID()
        shortcuts[idx].steps.insert(copy, at: index + 1)
        syncShortcut(shortcuts[idx])
    }

    /// 동작 실행 단축키 지정/변경 (중복 시 무시)
    func setShortcutCombo(_ shortcut: ShortcutItem, combo: HotKeyCombo) {
        if combo.isEmpty { return }
        if isDuplicate(combo: combo, excluding: shortcut.id) {
            Logger.info("ConfigStore", "[SHORTCUT] 중복 단축키 무시: \(combo.displayString)")
            return
        }
        guard let idx = shortcuts.firstIndex(where: { $0.id == shortcut.id }) else { return }
        // 이전 조합 해제
        if !shortcuts[idx].combo.isEmpty, shortcuts[idx].combo != combo {
            hotKeyService.unregister(shortcut.id)
        }
        shortcuts[idx].combo = combo
        _ = hotKeyService.register(shortcut.id, combo: combo)
        syncShortcut(shortcuts[idx])
        Logger.info("ConfigStore", "[SHORTCUT] 실행 단축키 지정: \(shortcut.name) → \(combo.displayString)")
    }

    /// 동작 단축키 해제
    func clearShortcutCombo(_ shortcut: ShortcutItem) {
        guard let idx = shortcuts.firstIndex(where: { $0.id == shortcut.id }) else { return }
        hotKeyService.unregister(shortcut.id)
        shortcuts[idx].combo = .empty
        syncShortcut(shortcuts[idx])
    }

    private func syncShortcut(_ shortcut: ShortcutItem) {
        guard let context = container?.mainContext else { return }
        let fetch = FetchDescriptor<PersistedShortcut>(predicate: #Predicate { $0.id == shortcut.id })
        if let found = try? context.fetch(fetch).first {
            found.name = shortcut.name
            found.comboKeyCode = shortcut.combo.keyCode
            found.comboModifiers = shortcut.combo.modifiers
            found.comboDisplayString = shortcut.combo.displayString
            found.stepsData = (try? JSONEncoder().encode(shortcut.steps)) ?? Data()
        }
        try? context.save()
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

    /// 단축키 중복 감지 (다른 binding/단축어와 충돌)
    func isDuplicate(combo: HotKeyCombo, excluding id: UUID) -> Bool {
        guard !combo.isEmpty else { return false }
        let bindingConflict = bindings.contains { $0.id != id && $0.combo == combo }
        if bindingConflict { return true }
        return shortcuts.contains { $0.id != id && $0.combo.matches(combo) }
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
        // 동작(단축어) 실행 단축키 먼저 확인
        if let shortcut = shortcuts.first(where: { $0.id == bindingID }) {
            Logger.info("ConfigStore", "[HOTKEY] 동작 실행: \(shortcut.name)")
            lastExecutedBindingID = bindingID
            actionExecutor.execute(shortcut)
            return
        }
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
        if let shortcut = shortcuts.first(where: { $0.id == lastID }) {
            actionExecutor.execute(shortcut)
            Logger.info("ConfigStore", "[REPEAT] 반복 실행: \(shortcut.name)")
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

    /// 매크로 녹화 중지 — 녹화된 키코드들을 반환 (바인딩은 만들지 않음)
    func stopMacroRecording() -> [UInt32] {
        let keyCodes = MacroRecorder.shared.recordedKeyCodes
        MacroRecorder.shared.stopRecording()
        isMacroRecording = false
        macroRecordedKeyCodes = []
        Logger.info("ConfigStore", "매크로 녹화 중지 — \(keyCodes.count)개 키")
        return keyCodes
    }

    /// 녹화된 키코드를 지정한 단축키로 매크로 바인딩 등록
    func recordMacro(keyCodes: [UInt32], combo: HotKeyCombo) -> Bool {
        guard !keyCodes.isEmpty, !combo.isEmpty else { return false }
        let target = keyCodes.map { String($0) }.joined(separator: ",")
        let binding = HotKeyBinding(
            combo: combo,
            actionType: .macro,
            target: target,
            title: "매크로 (\(keyCodes.count)키)",
            onlyWhenAppActive: false
        )
        addBinding(binding)
        Logger.info("ConfigStore", "매크로 바인딩 추가: \(binding.title) (\(combo.displayString))")
        return true
    }
}

enum MoveDirection {
    case up
    case down
}
