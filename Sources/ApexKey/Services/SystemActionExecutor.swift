import Foundation
import AppKit
import CoreGraphics

/// 시스템 동작(잠금/음소거/다크모드 등) 실행 서비스
enum SystemActionType: String, Codable, CaseIterable, Identifiable {
    case lock
    case mute
    case volumeUp
    case volumeDown
    case darkMode
    case sleep
    case displaySleep
    case screenSaver
    case dockRestart
    case finderRestart
    case minimizeFrontWindow
    case windowLeft40
    case windowLeft50
    case windowLeft60
    case windowRight40
    case windowRight50
    case windowRight60
    // v0.33 추가 — 트랙패드 제스처에서 바로 쓰도록 실제 구현한 동작
    case screenshot
    case newNote
    case quickNote
    case wallpaper
    case wakeDisplay
    case activateApp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lock:         return "system.action.lock".localized
        case .mute:         return "system.action.mute".localized
        case .volumeUp:     return "system.action.volume_up".localized
        case .volumeDown:   return "system.action.volume_down".localized
        case .darkMode:     return "system.action.dark_mode".localized
        case .sleep:        return "system.action.sleep".localized
        case .displaySleep: return "system.action.display_sleep".localized
        case .screenSaver:  return "system.action.screen_saver".localized
        case .dockRestart:  return "system.action.dock_restart".localized
        case .finderRestart: return "system.action.finder_restart".localized
        case .minimizeFrontWindow: return "system.action.minimize".localized
        case .windowLeft40:  return "system.action.window_left_40".localized
        case .windowLeft50:  return "system.action.window_left_50".localized
        case .windowLeft60:  return "system.action.window_left_60".localized
        case .windowRight40: return "system.action.window_right_40".localized
        case .windowRight50: return "system.action.window_right_50".localized
        case .windowRight60: return "system.action.window_right_60".localized
        case .screenshot:   return "system.action.screenshot".localized
        case .newNote:      return "system.action.new_note".localized
        case .quickNote:    return "system.action.quick_note".localized
        case .wallpaper:    return "system.action.wallpaper".localized
        case .wakeDisplay:  return "system.action.wake_display".localized
        case .activateApp:  return "system.action.activate_app".localized
        }
    }

    var systemImage: String {
        switch self {
        case .lock:         return "lock"
        case .mute:         return "speaker.slash"
        case .volumeUp:     return "speaker.wave.3"
        case .volumeDown:   return "speaker.wave.1"
        case .darkMode:     return "moon"
        case .sleep:        return "moon.zzz"
        case .displaySleep: return "display"
        case .screenSaver:  return "sparkles.tv"
        case .dockRestart:  return "dock.rectangle"
        case .finderRestart: return "folder"
        case .minimizeFrontWindow: return "arrow.down.right.and.arrow.up.left"
        case .windowLeft40, .windowLeft50, .windowLeft60:
            return "rectangle.lefthalf.filled"
        case .windowRight40, .windowRight50, .windowRight60:
            return "rectangle.righthalf.filled"
        case .screenshot:   return "camera.viewfinder"
        case .newNote:      return "note.text"
        case .quickNote:    return "note.text.badge.plus"
        case .wallpaper:    return "photo.on.rectangle"
        case .wakeDisplay:  return "sun.max"
        case .activateApp:  return "macwindow.on.rectangle"
        }
    }

    /// 실행에 추가 파라미터가 필요한가 (배경화면 이미지 경로, 활성화할 앱 번들ID)
    var requiresParameter: Bool {
        switch self {
        case .wallpaper, .activateApp: return true
        default: return false
        }
    }

    /// 파라미터 선택 UI 종류
    enum ParameterKind {
        case none
        /// 이미지 파일 선택
        case file
        /// 실행 중인 앱 선택
        case app
    }

    var parameterKind: ParameterKind {
        switch self {
        case .wallpaper: return .file
        case .activateApp: return .app
        default: return .none
        }
    }

    /// 윈도우 타일링 여부 (T-194)
    var isWindowTiling: Bool {
        switch self {
        case .windowLeft40, .windowLeft50, .windowLeft60,
             .windowRight40, .windowRight50, .windowRight60:
            return true
        default:
            return false
        }
    }

    /// 타일링 비율 (왼쪽/오른쪽 %). 타일링이 아니면 nil.
    var tilingPercent: Int? {
        switch self {
        case .windowLeft40, .windowRight40: return 40
        case .windowLeft50, .windowRight50: return 50
        case .windowLeft60, .windowRight60: return 60
        default: return nil
        }
    }

    /// 타일링 방향. 타일링이 아니면 nil.
    var tilingSide: WindowTiling.TilingSide? {
        switch self {
        case .windowLeft40, .windowLeft50, .windowLeft60: return .left
        case .windowRight40, .windowRight50, .windowRight60: return .right
        default: return nil
        }
    }
}

/// 전면 창 타일링 스크립트 생성 (T-194, 순수 — 단위테스트 대상).
///
/// 화면 크기는 호출부(Swift, `NSScreen` — 권한 불필요)가 넣어준다.
///
/// **2026-10-17 정정**: T-194에서 "AppleScript 안에서 `Finder`를 건드리면 Automation 권한이 없어
/// 실패한다"고 진단했지만, **실제 원인은 하드닝 런타임 자동화 엔타이틀먼트 누락**이었다
/// (`Sources/ApexKey/ApexKey.entitlements`, `docs/CHANGELOG.md` 2026-10-17 항목).
/// 지금은 Finder 자동화도 가능하다 — 다만 화면 크기를 `NSScreen`으로 넘기는 방식은
/// AppleEvent 왕복을 줄이고 Finder 창 유무와 무관하게 동작하므로 그대로 둔다.
/// 스크립트는 System Events(메뉴 명령과 동일 경로)에만 의존한다.
enum WindowTiling {
    enum TilingSide { case left, right }

    static func script(side: TilingSide, percent: Int, screenWidth: Int, screenHeight: Int) -> String {
        let tileW = (screenWidth * percent) / 100
        let x: Int
        switch side {
        case .left: x = 0
        case .right: x = screenWidth - tileW
        }
        return """
        tell application "System Events"
          set frontProc to first application process whose frontmost is true
          tell frontProc
            set frontWin to first window
            set position of frontWin to {\(x), 25}
            set size of frontWin to {\(tileW), \(screenHeight - 25)}
          end tell
        end tell
        """
    }
}

enum SystemActionExecutor {
    /// 기본 AppleScript — 고정 프리셋. 수정 불가 (프리셋 선택지만 제공한다).
    /// 윈도우 타일링 6종은 `WindowTiling.script`로 생성 (아래 execute 분기).
    private static let defaultAppleScripts: [SystemActionType: String] = [
        .lock: "tell application \"System Events\" to keystroke \"q\" using {control down, command down}",
        .mute: """
        set vol to output volume of (get volume settings)
        if vol > 0 then
            set volume output volume 0
        else
            set volume output volume 60
        end if
        """,
        .darkMode: "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode",
        .sleep: "do shell script \"pmset sleepnow\"",
        .displaySleep: "do shell script \"pmset displaysleepnow\"",
        .screenSaver: "do shell script \"open -a ScreenSaverEngine\"",
        .dockRestart: "do shell script \"killall Dock\"",
        .finderRestart: "do shell script \"killall Finder\"",
        .minimizeFrontWindow: "tell application \"System Events\" to keystroke \"m\" using command down"
    ]

    /// 시스템 동작 실행. 성공 여부 반환.
    @discardableResult
    static func execute(_ type: SystemActionType, parameter: String? = nil) -> Bool {
        switch type {
        case .volumeUp:
            return SystemVolume.adjust(by: EdgeSliderRecognizer.stepValue) != nil
        case .volumeDown:
            return SystemVolume.adjust(by: -EdgeSliderRecognizer.stepValue) != nil
        case .mute:
            // AppleScript 없는 순수 볼륨 토글
            return toggleMute()
        case .screenshot:
            return takeScreenshot()
        case .newNote:
            return runAppleScript(
                "tell application \"Notes\"\n activate\n make new note at folder \"Notes\"\nend tell",
                action: type
            )
        case .quickNote:
            return triggerQuickNote()
        case .wallpaper:
            return setWallpaper(path: parameter)
        case .wakeDisplay:
            return runShell("/usr/bin/caffeinate", arguments: ["-u", "-t", "1"], action: type)
        case .activateApp:
            return activateApp(bundleID: parameter)
        default:
            break
        }

        if let side = type.tilingSide, let percent = type.tilingPercent {
            guard let frame = NSScreen.main?.frame, frame.width > 0, frame.height > 25 else {
                Logger.error("E-MAC-SYS-8007", "화면 크기 조회 실패 — 타일링 취소")
                return false
            }
            let script = WindowTiling.script(
                side: side, percent: percent,
                screenWidth: Int(frame.width), screenHeight: Int(frame.height)
            )
            return runAppleScript(script, action: type)
        }
        let script = defaultAppleScripts[type] ?? ""
        guard !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return runAppleScript(script, action: type)
    }

    // MARK: - 개별 구현

    /// 대화형 영역 캡처 (⌘⇧4와 같은 크로스헤어). 파일은 데스크탑에 저장된다.
    private static func takeScreenshot() -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let name = "ApexKey Screenshot \(formatter.string(from: Date())).png"
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let path = desktop.appendingPathComponent(name).path
        // -i: 대화형 선택, -x: 소리 없음. 사용자가 취소하면 파일이 생기지 않는다.
        // 선택을 기다리는 동안 블로킹하지 않도록 프로세스만 띄우고 반환한다.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", path]
        do {
            try process.run()
            Logger.info("SystemActionExecutor", "스크린샷 캡처 시작: \(path)")
            return true
        } catch {
            Logger.error("E-MAC-SYS-8008", "스크린샷 실행 실패: \(error.localizedDescription)")
            return false
        }
    }

    /// 시스템 전역 Quick Note 단축키(fn+Q)를 합성한다.
    private static func triggerQuickNote() -> Bool {
        let keyCode: CGKeyCode = 12   // Q
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return false
        }
        down.flags = .maskSecondaryFn
        up.flags = .maskSecondaryFn
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        Logger.info("SystemActionExecutor", "빠른 메모 단축키(fn+Q) 합성")
        return true
    }

    private static func setWallpaper(path: String?) -> Bool {
        guard let path, !path.isEmpty else {
            Logger.error("E-MAC-SYS-8009", "배경화면 경로 없음")
            return false
        }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            Logger.error("E-MAC-SYS-8009", "배경화면 파일 없음: \(path)")
            return false
        }
        guard !NSScreen.screens.isEmpty else { return false }
        var applied = false
        for screen in NSScreen.screens {
            do {
                try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
                applied = true
            } catch {
                Logger.error("E-MAC-SYS-8009", "배경화면 적용 실패: \(error.localizedDescription)")
            }
        }
        guard applied else { return false }
        Logger.info("SystemActionExecutor", "배경화면 변경: \(path)")
        return true
    }

    private static func activateApp(bundleID: String?) -> Bool {
        guard let bundleID, !bundleID.isEmpty else {
            Logger.error("E-MAC-SYS-8010", "활성화할 앱 번들ID 없음")
            return false
        }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            // 실행 중이 아니면 새로 띄운다
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                Logger.info("SystemActionExecutor", "앱을 찾을 수 없음: \(bundleID)")
                return false
            }
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                if let error {
                    Logger.error("E-MAC-SYS-8011", "앱 실행 실패: \(error.localizedDescription)")
                }
            }
            return true
        }
        return app.activate(options: [.activateAllWindows])
    }

    private static func runShell(_ path: String, arguments: [String], action: SystemActionType) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        do {
            try process.run()
            Logger.info("SystemActionExecutor", "\(action.displayName) 실행")
            return true
        } catch {
            Logger.error("E-MAC-SYS-8012", "\(action.displayName) 실행 실패: \(error.localizedDescription)")
            return false
        }
    }

    private static func toggleMute() -> Bool {
        let source = defaultAppleScripts[.mute] ?? ""
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let r = ScriptExecutor.runAppleScript(source)
        if !r.success {
            Logger.error("E-MAC-SYS-8002", "음소거 실행 실패: \(r.errorOutput.prefix(500))")
            return false
        }
        Logger.info("SystemActionExecutor", "음소거 토글")
        return true
    }

    private static func runAppleScript(_ script: String, action: SystemActionType) -> Bool {
        let r = ScriptExecutor.runAppleScript(script)
        if !r.success {
            Logger.error("E-MAC-SYS-8002", "\(action.displayName) 실행 실패: \(r.errorOutput.prefix(500))")
            return false
        }
        Logger.info("SystemActionExecutor", "\(action.displayName) 실행")
        return true
    }
}
