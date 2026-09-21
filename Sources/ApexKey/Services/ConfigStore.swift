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
    @Published var showPalette = false
    /// 매크로 녹화 상태
    @Published var isMacroRecording = false
    @Published var macroRecordedKeyCodes: [UInt32] = []
    @Published var menuHUDHotkey: HotKeyCombo
    @Published var toggleHotkey: HotKeyCombo
    @Published var paletteHotkey: HotKeyCombo
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
    @Published var showSuccessToast: Bool = true {
        didSet { UserDefaults.standard.set(showSuccessToast, forKey: PrefKeys.showSuccessToast) }
    }
    @Published var appLanguage: String? = nil {
        didSet {
            if let code = appLanguage, !code.isEmpty {
                UserDefaults.standard.set([code], forKey: "AppleLanguages")
                UserDefaults.standard.set(code, forKey: PrefKeys.appLanguage)
            } else {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                UserDefaults.standard.removeObject(forKey: PrefKeys.appLanguage)
            }
            UserDefaults.standard.synchronize()
            Logger.info("ConfigStore", "앱 언어 설정 변경: \(appLanguage ?? "시스템") — 재시작 필요")
        }
    }
    var container: ModelContainer?
    private var cancellables = Set<AnyCancellable>()

    let hotKeyService = HotKeyService.shared
    let actionExecutor = ActionExecutor.shared

    /// ⇧⌥A 패널 토글 핫키 전용 등록 ID (bindings 배열 밖의 예약 ID)
    let panelToggleID = UUID()

    /// ⌘⇧↩ 마지막 바인딩 반복 전용 등록 ID
    let repeatLastID = UUID()

    /// ⌘⌥K 명령 팔레트 전용 등록 ID
    let paletteID = UUID()

    /// ⇧⌥S Menu HUD 전용 등록 ID (전면 앱 단축키 표시)
    let menuHUDID = UUID()

    /// 마지막으로 실행된 바인딩 ID (반복용)
    var lastExecutedBindingID: UUID?



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
        self.toggleHotkey = Self.loadHotkey(forKey: PrefKeys.panelToggleHotkey, fallback: Self.defaultToggleHotkey)
        self.menuHUDHotkey = Self.loadHotkey(forKey: PrefKeys.menuHUDHotkey, fallback: Self.defaultMenuHUDHotkey)
        self.paletteHotkey = Self.loadHotkey(forKey: PrefKeys.paletteHotkey, fallback: Self.defaultPaletteHotkey)
        self.showNoShortcutItems = defaults.object(forKey: PrefKeys.showNoShortcutItems) == nil ? true : defaults.bool(forKey: PrefKeys.showNoShortcutItems)
        self.showSuccessToast = defaults.object(forKey: PrefKeys.showSuccessToast) == nil ? true : defaults.bool(forKey: PrefKeys.showSuccessToast)
        self.showSystemApps = defaults.object(forKey: PrefKeys.showSystemApps) == nil ? true : defaults.bool(forKey: PrefKeys.showSystemApps)
        // 앱 언어 설정 로드 (nil = 시스템)
        if let savedLang = defaults.string(forKey: PrefKeys.appLanguage), !savedLang.isEmpty {
            self.appLanguage = savedLang
        }
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
                if bindingID == self.paletteID {
                    // ⌘⌥K → 명령 팔레트 토글
                    self.showPalette.toggle()
                    Logger.info("ConfigStore", "[HOTKEY] 명령 팔레트 토글")
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
        // ⌘⌥K 명령 팔레트 핫키 등록
        _ = hotKeyService.register(paletteID, combo: paletteHotkey)
        Logger.info("ConfigStore", "[HOTKEY] 명령 팔레트 핫키 등록: \(paletteHotkey.displayString)")
        // ⇧⌥S Menu HUD 핫키 등록
        _ = hotKeyService.register(menuHUDID, combo: menuHUDHotkey)
        Logger.info("ConfigStore", "[HOTKEY] Menu HUD 핫키 등록: \(menuHUDHotkey.displayString)")
    }

    func load() {
        guard let context = container?.mainContext else { return }
        let appFetch = FetchDescriptor<PersistedApp>()
        let bindingFetch = FetchDescriptor<PersistedBinding>()
        let persistedApps = fetchContext(context, appFetch)
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
        if migrated { saveContext(context) }
        let persistedBindings = fetchContext(context, bindingFetch)
        bindings = persistedBindings.map { $0.toBinding() }
        // 시스템 탭이 프리셋 통합으로 제거되어 저장된 시스템 바인딩은 전부 해제한다.
        let legacySystemBindings = bindings.filter { $0.actionType == .system }
        if !legacySystemBindings.isEmpty {
            legacySystemBindings.forEach { hotKeyService.unregister($0.id) }
            bindings.removeAll { $0.actionType == .system }
            for binding in legacySystemBindings {
                let fetch = FetchDescriptor<PersistedBinding>(predicate: #Predicate { $0.id == binding.id })
                if let found = fetchContext(context, fetch).first {
                    context.delete(found)
                }
            }
            saveContext(context)
            Logger.info("ConfigStore", "기존 시스템 바인딩 \(legacySystemBindings.count)개 해제 (프리셋 통합)")
        }
        let scriptFetch = FetchDescriptor<PersistedScript>()
        let persistedScripts = fetchContext(context, scriptFetch)
        scripts = persistedScripts.map { $0.toScript() }
        let shortcutFetch = FetchDescriptor<PersistedShortcut>()
        let persistedShortcuts = fetchContext(context, shortcutFetch)
        shortcuts = persistedShortcuts.map { $0.toShortcut() }
        if apps.isEmpty {
            // 첫 실행 시 설치된 앱 자동 로드
            let installed = AppFinder.installedApps()
            installed.forEach { context.insert(PersistedApp.from($0)) }
            do {
                try context.save()
                apps = installed
            } catch {
                Logger.error("E-MAC-STORE-5001", "설치 앱 초기 저장 실패: \(error.localizedDescription)")
            }
        }
        pruneRemovedApps()
        if showSystemApps {
            addSystemAppsIfMissing()
        }
        ensureADBWifiSample()
        configureAutomationManager()
    }

    /// ADB Wi-Fi 연결 샘플 동작 — 고정 프리셋이 시스템 탭으로 이관되어
    /// 기존에 설치된 잔재(Android Untether/Mirror/Remote)만 1회 정리한다.
    func ensureADBWifiSample() {
        removeLegacyAndroidShortcutsIfNeeded()
    }

    /// 설치 시 기본 제공되는 고정 동작 프리셋 — 현재 없음.
    /// Android 미러는 시스템 탭(`SystemActionType.androidMirror`)으로 이관됨.
    func ensureBuiltInShortcuts() {
        removeLegacyAndroidShortcutsIfNeeded()
    }

    /// 과거 동작 탭 고정 프리셋의 잔재를 저장소에서 1회 삭제.
    /// 대상: "Android Untether (언테더)", "Android Mirror (미러)",
    /// "Android Remote", 구 샘플명 "ADB Wi-Fi 연결".
    func removeLegacyAndroidShortcutsIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: PrefKeys.didCleanupLegacyAndroid) else { return }
        defaults.set(true, forKey: PrefKeys.didCleanupLegacyAndroid)
        // 정리 후 목록이 비어도 예시 동작을 다시 만들지 않음
        defaults.set(true, forKey: PrefKeys.didSeedSamples)
        let legacyNames = ["Android Untether (언테더)", "Android Mirror (미러)", "Android Remote", "ADB Wi-Fi 연결"]
        let targets = shortcuts.filter { legacyNames.contains($0.name) }
        guard !targets.isEmpty else { return }
        guard let context = container?.mainContext else { return }
        for target in targets {
            if !target.combo.isEmpty {
                hotKeyService.unregister(target.id)
            }
            shortcuts.removeAll { $0.id == target.id }
            let fetch = FetchDescriptor<PersistedShortcut>(predicate: #Predicate { $0.id == target.id })
            if let found = fetchContext(context, fetch).first {
                context.delete(found)
            }
            Logger.info("FEATURE", "과거 Android 고정 동작 정리: \(target.name)")
        }
        saveContext(context)
    }


    // MARK: - 저장 헬퍼

    /// ModelContext 저장 + 실패 시 에러 로그 (R-05: try? 묵살 해소)
    /// 호출 위치 식별은 #function 기본값으로 자동 기록한다.
    func saveContext(_ context: ModelContext, tag: String = #function) {
        do {
            try context.save()
        } catch {
            Logger.error("E-MAC-STORE-5001", "\(tag) 저장 실패: \(error.localizedDescription)")
        }
    }

    /// ModelContext 조회 + 실패 시 에러 로그 후 빈 배열 (R-05)
    func fetchContext<T: PersistentModel>(_ context: ModelContext, _ descriptor: FetchDescriptor<T>, tag: String = #function) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            Logger.error("E-MAC-STORE-5004", "\(tag) 조회 실패: \(error.localizedDescription)")
            return []
        }
    }








}

/// 설치 시 기본 제공되는 고정 동작 프리셋 — 현재 없음 (호환용 스텁).
/// Android 미러는 시스템 탭(`SystemActionType.androidMirror`)으로 이관됨.
/// 과거 테스트(`BuiltInShortcutPresets.all`) 호환을 위해 빈 목록을 유지한다.
enum BuiltInShortcutPresets {
    static let all: [ShortcutItem] = []
}

enum MoveDirection {
    case up
    case down
}
