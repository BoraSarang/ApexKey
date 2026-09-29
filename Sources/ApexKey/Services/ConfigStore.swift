import Foundation
import SwiftData
import AppKit
import Combine

/// 앱 전역 상태 저장소 (SwiftData + HotKeyService 연동)
@MainActor
final class ConfigStore: ObservableObject {
    /// 설정 영속 대상 — 테스트에서는 전용 suite를 주입해 실제 설정을 오염시키지 않는다 (E-MAC-STORE-5009)
    private let defaults: UserDefaults

    @Published var apps: [AppItem] = []
    @Published var bindings: [HotKeyBinding] = []
    @Published var scripts: [ScriptItem] = []
    @Published var shortcuts: [ShortcutItem] = []
    /// 숨김 앱 표시 여부 — 설정 토글이 매 실행 리셋되지 않도록 영속화한다 (E-MAC-STORE-5008)
    /// 다른 모든 표시 설정과 동일한 `didSet` + `PrefKeys` + `init()` 복원 패턴을 따른다.
    @Published var showHiddenApps: Bool {
        didSet {
            guard showHiddenApps != oldValue else { return }
            defaults.set(showHiddenApps, forKey: Self.PrefKeys.showHiddenApps)
        }
    }
    @Published var showPalette = false
    /// 매크로 녹화 상태
    @Published var isMacroRecording = false
    @Published var macroRecordedKeyCodes: [UInt32] = []
    @Published var menuHUDHotkey: HotKeyCombo
    @Published var toggleHotkey: HotKeyCombo
    @Published var paletteHotkey: HotKeyCombo
    @Published var alwaysOnTop = false {
        didSet { defaults.set(alwaysOnTop, forKey: PrefKeys.alwaysOnTop) }
    }
    @Published var showInMenuBar = true {
        didSet { defaults.set(showInMenuBar, forKey: PrefKeys.showInMenuBar) }
    }
    @Published var showInDock = false {
        didSet { defaults.set(showInDock, forKey: PrefKeys.showInDock) }
    }
    @Published var menuHUDStyle: MenuHUDStyle = .floatingWindow {
        didSet { defaults.set(menuHUDStyle.rawValue, forKey: PrefKeys.menuHUDStyle) }
    }
    @Published var showNoShortcutItems: Bool = true {

        didSet { defaults.set(showNoShortcutItems, forKey: PrefKeys.showNoShortcutItems) }
    }
    @Published var showSystemApps: Bool = true {
        didSet {
            defaults.set(showSystemApps, forKey: PrefKeys.showSystemApps)
            if showSystemApps {
                addSystemAppsIfMissing()
            }
        }
    }
    @Published var showSuccessToast: Bool = true {
        didSet { defaults.set(showSuccessToast, forKey: PrefKeys.showSuccessToast) }
    }
    @Published var updateState: UpdateState = .idle
    @Published var updateCheckFrequency: UpdateCheckFrequency = .weekly {
        didSet { defaults.set(updateCheckFrequency.rawValue, forKey: PrefKeys.updateFrequency) }
    }
    /// 마지막 업데이트 확인 시각 (UserDefaults 영속 — 재실행해도 주기 유지)
    @Published var updateCheckedAt: Date? {
        didSet {
            if let date = updateCheckedAt {
                defaults.set(date.timeIntervalSince1970, forKey: PrefKeys.updateLastChecked)
            } else {
                defaults.removeObject(forKey: PrefKeys.updateLastChecked)
            }
        }
    }
    /// 앱 실행 시점 — atLaunch 주기 판정용 ("이번 실행에서 아직 확인 안 했으면")
    let launchDate = Date()
    @Published var appLanguage: String? = nil {
        didSet {
            if let code = appLanguage, !code.isEmpty {
                // AppleLanguages 단일 출처는 LanguageManager (E-MAC-UX-9008)
                LanguageManager.shared.setLanguage(code)
                defaults.set(code, forKey: PrefKeys.appLanguage)
            } else {
                LanguageManager.shared.setLanguage(nil)
                defaults.removeObject(forKey: PrefKeys.appLanguage)
            }
            Logger.info("ConfigStore", "앱 언어 설정 변경: \(appLanguage ?? "시스템") — 재시작 필요")
        }
    }
    var container: ModelContainer?
    /// 원본 blob 디코딩 실패 컬럼 — 해당 컬럼은 sync 시 원본 Data 유지 (P0-3)
    var corruptedShortcutBlobColumns: [UUID: Set<StoreBlobColumn>] = [:]
    /// 손상 시점의 fallback 값 스냅샷 (E-MAC-STORE-5010)
    ///
    /// 복구 판정 기준. 왕복 검증만으로는 fallback(`[]`)과 정상적인 빈 값을 구별할 수 없다.
    /// 여기 기록된 바이트와 **같으면** "아직 손상 직후 그대로"이므로 잠금을 유지한다.
    var corruptedBlobFallbackBytes: [UUID: [StoreBlobColumn: Data]] = [:]
    /// 단계 편집 저장을 합치는 스케줄러 (E-MAC-STORE-5011)
    ///
    /// `ConfigStore`가 `@MainActor`이므로 실행 큐는 `.main`이다. 창을 닫을 때
    /// `flushPendingSaves()`를 불러야 예약된 저장이 실제 반영된다.
    let shortcutSaveScheduler = CoalescingScheduler<UUID>()
    /// 대기 중인 저장을 즉시 기록한다 (창 종료·앱 종료 경로)
    func flushPendingSaves() { shortcutSaveScheduler.flushNow() }
    /// 저장소 손상 격리 후 재생성된 경우 백업 경로 (UI 안내용, P0-2)
    @Published var storeRecoveryBackupPath: String? = nil
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



    /// 앱 전역 저장소 생성 — 실제 앱 진입점
    convenience init() {
        self.init(storeDirectory: nil, defaults: .standard, seedInstalledApps: true, registerSystemIntegrations: true)
    }

    /// 저장소 경로와 전역 부작용을 주입 가능한 초기화 (E-MAC-STORE-5009)
    ///
    /// 왜 주입 가능하게 했나: `storeURL`이 하드코딩돼 있어 `ConfigStore()`를 인스턴스화하는
    /// 테스트가 **0건**이었다. 바인딩 추가·교체·삭제, 앱 제거 시 고아 핫키 정리,
    /// 워크플로우 저장 같은 모든 뮤테이션 경로가 검증되지 않은 상태였다.
    ///
    /// - Parameters:
    ///   - storeDirectory: `nil`이면 `~/Library/Application Support/com.borasarang.ApexKey`.
    ///     테스트는 임시 디렉터리를 주입해 **실제 사용자 저장소를 건드리지 않는다.**
    ///   - defaults: 테스트는 전용 suite를 주입해 실제 설정을 오염시키지 않는다.
    ///   - seedInstalledApps: `false`면 설치 앱 자동 로드·시스템 앱 시딩을 건너뛴다.
    ///     `true`면 앱 목록이 수백 개가 되어 검증이 무의미해진다.
    ///   - registerSystemIntegrations: `false`면 Carbon 핫키 등록·자동화 매니저 연결·
    ///     핫키 이벤트 구독을 하지 않는다. **`HotKeyService.shared`는 싱글턴이라
    ///     테스트가 오염시키면 다른 테스트가 깨진다** (v0.21에서 실수 1건).
    init(
        storeDirectory: URL?,
        defaults: UserDefaults,
        seedInstalledApps: Bool,
        registerSystemIntegrations: Bool
    ) {
        self.defaults = defaults
        if !defaults.bool(forKey: PrefKeys.showInMenuBar), defaults.object(forKey: PrefKeys.showInMenuBar) == nil {
            defaults.set(true, forKey: PrefKeys.showInMenuBar)
        }
        if !defaults.bool(forKey: PrefKeys.showInDock), defaults.object(forKey: PrefKeys.showInDock) == nil {
            defaults.set(false, forKey: PrefKeys.showInDock)
        }
        // 항상 위에: 저장값 복원 (강제 리셋 제거 — E-MAC-UX-9001)
        self.alwaysOnTop = defaults.bool(forKey: PrefKeys.alwaysOnTop)
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
        self.toggleHotkey = Self.loadHotkey(forKey: PrefKeys.panelToggleHotkey, fallback: Self.defaultToggleHotkey, defaults: defaults)
        self.menuHUDHotkey = Self.loadHotkey(forKey: PrefKeys.menuHUDHotkey, fallback: Self.defaultMenuHUDHotkey, defaults: defaults)
        self.paletteHotkey = Self.loadHotkey(forKey: PrefKeys.paletteHotkey, fallback: Self.defaultPaletteHotkey, defaults: defaults)
        self.showNoShortcutItems = defaults.object(forKey: PrefKeys.showNoShortcutItems) == nil ? true : defaults.bool(forKey: PrefKeys.showNoShortcutItems)
        self.showSuccessToast = defaults.object(forKey: PrefKeys.showSuccessToast) == nil ? true : defaults.bool(forKey: PrefKeys.showSuccessToast)
        self.showSystemApps = defaults.object(forKey: PrefKeys.showSystemApps) == nil ? true : defaults.bool(forKey: PrefKeys.showSystemApps)
        self.showHiddenApps = defaults.bool(forKey: PrefKeys.showHiddenApps)
        // 업데이트 확인 주기·마지막 확인 시각 로드 (기본 weekly)
        if let raw = defaults.string(forKey: PrefKeys.updateFrequency),
           let frequency = UpdateCheckFrequency(rawValue: raw) {
            self.updateCheckFrequency = frequency
        }
        let lastChecked = defaults.double(forKey: PrefKeys.updateLastChecked)
        if lastChecked > 0 {
            self.updateCheckedAt = Date(timeIntervalSince1970: lastChecked)
        }
        // 앱 언어 설정 로드 (nil = 시스템)
        if let savedLang = defaults.string(forKey: PrefKeys.appLanguage), !savedLang.isEmpty {
            self.appLanguage = savedLang
        }
        // 전용 저장소 경로 사용 — 기본 경로(~ibrary/Application Support/default.store)는
        // 다른 SwiftData 앱과 공유되어 스키마 충돌로 컨테이너 생성이 실패할 수 있음
        //
        // 스키마는 `ConfigMigrationPlan.currentSchema`(최신 버전)를 사용한다 (E-MAC-STORE-5007).
        // 여기서 무버전 `Schema([...])`로 되돌리면 향후 필드 추가 시 기존 store가
        // 열리지 않아 `quarantineStore` → 사용자 설정 전체 격리가 된다.
        let schema = ConfigMigrationPlan.currentSchema
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        // 경로가 주입되면 그것을 쓴다 (테스트 격리, E-MAC-STORE-5009)
        let resolvedStoreDirectory = storeDirectory
            ?? appSupport.appendingPathComponent("com.borasarang.ApexKey", isDirectory: true)
        let storeURL = resolvedStoreDirectory.appendingPathComponent("default.store")
        do {
            try FileManager.default.createDirectory(at: resolvedStoreDirectory, withIntermediateDirectories: true)
        } catch {
            Logger.error("E-MAC-STORE-5001", "저장소 디렉터리 생성 실패 (\(resolvedStoreDirectory.path)): \(error.localizedDescription)")
        }
        // 구 기본 경로 → 전용 경로 1회 이관 (P0-1)
        // 경로가 주입된 경우(=테스트)에는 실제 사용자 저장소를 건드리지 않으므로 이관하지 않는다.
        if storeDirectory == nil {
            Self.migrateLegacyStoreIfNeeded(appSupport: appSupport, storeDirectory: resolvedStoreDirectory, storeURL: storeURL)
        }
        func makeContainer() throws -> ModelContainer {
            try ModelContainer(
                for: schema,
                migrationPlan: ConfigMigrationPlan.self,
                configurations: [ModelConfiguration(schema: schema, url: storeURL)]
            )
        }
        do {
            container = try makeContainer()
            load(seedInstalledApps: seedInstalledApps, registerSystemIntegrations: registerSystemIntegrations)
        } catch {
            Logger.error("E-MAC-STORE-5001", "ModelContainer 생성 실패 (\(storeURL.path)): \(error.localizedDescription)")
            // 손상 store 격리 후 재시도 — 실패 시 무음 no-op 방지 (P0-2)
            if let backupPath = Self.quarantineStore(at: storeURL) {
                do {
                    container = try makeContainer()
                    storeRecoveryBackupPath = backupPath
                    Logger.error("E-MAC-STORE-5006", "손상 저장소 격리 후 재생성 성공 — 이전 데이터 백업: \(backupPath)")
                    load(seedInstalledApps: seedInstalledApps, registerSystemIntegrations: registerSystemIntegrations)
                } catch {
                    Logger.error("E-MAC-STORE-5001", "저장소 재생성 실패 (\(storeURL.path)): \(error.localizedDescription)")
                }
            }
        }

        // 전역 통합(핫키·자동화)은 테스트에서 오염을 남기므로 통째로 건너뛴다
        guard registerSystemIntegrations else {
            if !seedInstalledApps {
                Logger.info("ConfigStore", "[TEST] 전역 통합 비활성 — 시드 없음, 핫키 미등록")
            }
            return
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
                    // ⌘⇧↩ → 사이보그 모드 대기 중이면 계속, 아니면 마지막 바인딩 반복 (P0-5)
                    if self.actionExecutor.resumePauseUntilInput() {
                        return
                    }
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

    /// 저장소 → 메모리 복원
    /// - Parameters:
    ///   - seedInstalledApps: `false`면 설치 앱 자동 로드·시스템 앱 시딩을 건너뛴다 (E-MAC-STORE-5009)
    ///   - registerSystemIntegrations: `false`면 자동화 매니저 연결을 건너뛴다
    func load(seedInstalledApps: Bool = true, registerSystemIntegrations: Bool = true) {
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
        // 디코딩 실패 blob 컬럼 기록 — 이후 sync가 원본을 덮어쓰지 않도록 (P0-3)
        corruptedShortcutBlobColumns.removeAll()
        corruptedBlobFallbackBytes.removeAll()
        for p in persistedShortcuts {
            let corrupt = p.undecodableBlobColumns()
            if !corrupt.isEmpty {
                corruptedShortcutBlobColumns[p.id] = corrupt
                // 복구 판정 기준: 손상 시점의 fallback 값 (E-MAC-STORE-5010)
                var snapshots: [StoreBlobColumn: Data] = [:]
                for c in corrupt { snapshots[c] = p.fallbackBlobBytes(c) }
                corruptedBlobFallbackBytes[p.id] = snapshots
                Logger.error("E-MAC-STORE-5003", "blob 디코딩 실패 — 해당 컬럼 쓰기 가드: \(p.name) (\(corrupt.map(\.rawValue).sorted().joined(separator: ",")))")
            }
        }
        shortcuts = persistedShortcuts.map { $0.toShortcut() }
        // 시딩(설치 앱 자동 로드)은 테스트에서 비활성화한다 (E-MAC-STORE-5009).
        // 비활성화해도 `pruneRemovedApps()`는 **항상** 돈다 — 경로가 사라진 앱과
        // 그 고아 핫키를 정리하는 정합성 로직이라 시딩과 무관하다.
        if seedInstalledApps {
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
            if showSystemApps {
                addSystemAppsIfMissing()
            }
        }
        pruneRemovedApps()
        ensureADBWifiSample()
        if registerSystemIntegrations {
            configureAutomationManager()
        }
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

    /// 구 기본 경로(~/Library/Application Support/default.store) → 전용 디렉터리 1회 이관 (P0-1)
    /// store 본체와 SQLite sidecar(`-wal`/`-shm`)를 함께 이동한다.
    nonisolated static func migrateLegacyStoreIfNeeded(
        appSupport: URL,
        storeDirectory: URL,
        storeURL: URL,
        defaults: UserDefaults = .standard
    ) {
        guard !defaults.bool(forKey: PrefKeys.didMigrateLegacyStore) else { return }
        defaults.set(true, forKey: PrefKeys.didMigrateLegacyStore)
        let fm = FileManager.default
        let legacyURL = appSupport.appendingPathComponent("default.store")
        guard fm.fileExists(atPath: legacyURL.path) else { return }
        if fm.fileExists(atPath: storeURL.path) {
            Logger.info("ConfigStore", "레거시 저장소 존재하나 신규 경로 우선 — 구 경로 보관: \(legacyURL.path)")
            return
        }
        do {
            try fm.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
            for suffix in ["", "-wal", "-shm"] {
                let src = URL(fileURLWithPath: legacyURL.path + suffix)
                let dst = URL(fileURLWithPath: storeURL.path + suffix)
                guard fm.fileExists(atPath: src.path) else { continue }
                if fm.fileExists(atPath: dst.path) {
                    try fm.removeItem(at: dst)
                }
                try fm.moveItem(at: src, to: dst)
            }
            Logger.info("ConfigStore", "레거시 저장소 이관 완료: \(legacyURL.path) → \(storeURL.path)")
        } catch {
            Logger.error("E-MAC-STORE-5005", "레거시 저장소 이관 실패: \(error.localizedDescription)")
        }
    }

    /// 컨테이너 생성 실패 시 store + sidecar를 `.corrupt-{stamp}`로 이동 (P0-2)
    /// - Returns: 본체 백업 경로 (이동 성공 시), 실패 시 nil
    @discardableResult
    nonisolated static func quarantineStore(at storeURL: URL) -> String? {
        let fm = FileManager.default
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        var primaryBackup: URL?
        for suffix in ["", "-wal", "-shm"] {
            let src = URL(fileURLWithPath: storeURL.path + suffix)
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = URL(fileURLWithPath: storeURL.path + ".corrupt-\(stamp)" + suffix)
            do {
                try fm.moveItem(at: src, to: dst)
                if suffix.isEmpty { primaryBackup = dst }
            } catch {
                Logger.error("E-MAC-STORE-5001", "저장소 격리 실패 (\(src.path)): \(error.localizedDescription)")
            }
        }
        return primaryBackup?.path
    }

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

