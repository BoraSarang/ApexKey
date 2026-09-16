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
    /// 매크로 녹화 상태
    @Published var isMacroRecording = false
    @Published var macroRecordedKeyCodes: [UInt32] = []
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

    /// ⌥⌘Space Quick Launcher 전용 등록 ID
    let quickLauncherID = UUID()

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
        self.toggleHotkey = Self.defaultToggleHotkey
        self.menuHUDHotkey = Self.defaultMenuHUDHotkey
        self.showNoShortcutItems = defaults.object(forKey: PrefKeys.showNoShortcutItems) == nil ? true : defaults.bool(forKey: PrefKeys.showNoShortcutItems)
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
        let scriptFetch = FetchDescriptor<PersistedScript>()
        let persistedScripts = fetchContext(context, scriptFetch)
        scripts = persistedScripts.map { $0.toScript() }
        let shortcutFetch = FetchDescriptor<PersistedShortcut>()
        let persistedShortcuts = fetchContext(context, shortcutFetch)
        shortcuts = persistedShortcuts.map { $0.toShortcut() }
        // 첫 실행(저장 아무것도 없음)이면 예시 단축어 3개 생성 (마이그레이션 아님)
        if shortcuts.isEmpty {
            seedSampleShortcuts(context: context)
        }
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

    /// ADB Wi-Fi 연결 샘플 동작 — 이름 기준으로 없으면 1회 생성 (기존 사용자도 받음)
    /// USB로 연결된 안드로이드의 IP를 읽어 무선 ADB(5555)로 전환한다.
    /// 고정 프리셋(아래 BuiltInShortcutPresets)으로 이관됨 — 호환용으로 유지.
    func ensureADBWifiSample() {
        ensureBuiltInShortcuts()
    }

    /// 설치 시 기본 제공되는 고정 동작 프리셋을 이름 기준으로 보충.
    /// 시스템 탭(SystemActionType)과 같은 취급: 코드에 고정, 단축키(combo) 없이 제공,
    /// 사용자는 실행·단축키 지정·삭제 가능. 삭제한 것은 다시 만들지 않음.
    func ensureBuiltInShortcuts() {
        guard let context = container?.mainContext else { return }
        var added = false
        for preset in BuiltInShortcutPresets.all {
            guard !shortcuts.contains(where: { $0.name == preset.name }) else { continue }
            context.insert(PersistedShortcut.from(preset))
            shortcuts.append(preset)
            added = true
            Logger.info("FEATURE", "동작 고정 프리셋 제공: \(preset.name)")
        }
        if added { saveContext(context) }
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

/// 설치 시 기본 제공되는 고정 동작 프리셋 (시스템 탭과 동급 취급).
/// - 코드에 고정: 설치·업데이트 후에도 이름 기준으로 자동 보충
/// - 단축키(combo) 없음: 사용자가 필요할 때 지정
/// - 삭제 가능: 사용자가 지운 것은 다시 만들지 않음 (이름 기준 존재 확인)
enum BuiltInShortcutPresets {
    static let all: [ShortcutItem] = [androidUntether, androidMirror]

    /// Android Untether (언테더) — USB 연결 기기의 IP로 ADB 무선 연결
    static let androidUntether = ShortcutItem(
        name: "Android Untether (언테더)",
        steps: [ShortcutStep(
            type: .script,
            target: """
            adb tcpip 5555
            sleep 1
            IP=$(adb shell ip route | awk '{print $9}' | head -1)
            if [ -z "$IP" ]; then echo "IP를 찾지 못했습니다. USB 연결을 확인하세요."; exit 1; fi
            adb connect "$IP:5555"
            echo "연결 완료: $IP:5555"
            """,
            title: "케이블 없이 무선으로 기기 디버깅 연결"
        )],
        description: "USB 연결된 안드로이드의 IP로 ADB 무선 연결"
    )

    /// Android Mirror (미러) — 연결된 기기 화면을 scrcpy로 띄움
    static let androidMirror = ShortcutItem(
        name: "Android Mirror (미러)",
        steps: [ShortcutStep(
            type: .script,
            target: """
            export PATH="$PATH:/opt/homebrew/bin"

            DEVICE=$(adb devices | grep -v "List" | grep "device$")
            if [ -z "$DEVICE" ]; then
              echo "연결된 기기가 없습니다."
              exit 1
            fi


            nohup scrcpy --show-touches --stay-awake --legacy-paste --max-size=1024 --video-bit-rate=2M --max-fps=30 > /dev/null 2>&1 &
            disown
            """,
            title: "연결된 기기 화면을 맥에 띄우고 마우스·키보드로 조작"
        )],
        description: ""
    )
}

enum MoveDirection {
    case up
    case down
}
