import Foundation
import AppKit

/// 시스템 동작(잠금/음소거/다크모드 등) 실행 서비스
enum SystemActionType: String, Codable, CaseIterable, Identifiable {
    case lock
    case mute
    case darkMode
    case sleep
    case displaySleep
    case screenSaver
    case dockRestart
    case finderRestart
    case androidMirror

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lock:         return "system.action.lock".localized
        case .mute:         return "system.action.mute".localized
        case .darkMode:     return "system.action.dark_mode".localized
        case .sleep:        return "system.action.sleep".localized
        case .displaySleep: return "system.action.display_sleep".localized
        case .screenSaver:  return "system.action.screen_saver".localized
        case .dockRestart:  return "system.action.dock_restart".localized
        case .finderRestart: return "system.action.finder_restart".localized
        case .androidMirror: return "system.action.android_mirror".localized
        }
    }

    var systemImage: String {
        switch self {
        case .lock:         return "lock"
        case .mute:         return "speaker.slash"
        case .darkMode:     return "moon"
        case .sleep:        return "moon.zzz"
        case .displaySleep: return "display"
        case .screenSaver:  return "sparkles.tv"
        case .dockRestart:  return "dock.rectangle"
        case .finderRestart: return "folder"
        case .androidMirror: return "apps.iphone"
        }
    }
}

enum SystemActionExecutor {
    private static let appleScripts: [SystemActionType: String] = [
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
        .finderRestart: "do shell script \"killall Finder\""
    ]

    /// Android Remote Mirror (scrcpy) — 외부 스크립트 파일이 단일 소스.
    /// 파일 수정이 앱에 즉시 반영된다 (재빌드 불필요).
    static let androidMirrorScriptPath =
        "/Users/lee/Documents/AGENTS/development/scripts/scrcpy_run.sh"

    /// 시스템 동작 실행. 성공 여부 반환.
    @discardableResult
    static func execute(_ type: SystemActionType) -> Bool {
        if type == .mute {
            // AppleScript 없는 순수 볼륨 토글
            return toggleMute()
        }
        if type == .androidMirror {
            let result = ActionExecutor.shared.runScriptFileResult(androidMirrorScriptPath)
            Logger.info("SystemActionExecutor", "Android Remote Mirror (scrcpy) 실행 (success=\(result.success))")
            return result.success
        }
        guard let script = appleScripts[type] else { return false }
        return runAppleScript(script, action: type)
    }

    private static func toggleMute() -> Bool {
        guard let src = NSAppleScript(source: appleScripts[.mute]!) else {
            Logger.error("E-MAC-SYS-8001", "음소거 스크립트 생성 실패")
            return false
        }
        var error: NSDictionary?
        src.executeAndReturnError(&error)
        if let error {
            Logger.error("E-MAC-SYS-8002", "음소거 실행 실패: \(error)")
            return false
        }
        Logger.info("SystemActionExecutor", "음소거 토글")
        return true
    }

    private static func runAppleScript(_ script: String, action: SystemActionType) -> Bool {
        guard let src = NSAppleScript(source: script) else {
            Logger.error("E-MAC-SYS-8001", "\(action.displayName) 스크립트 생성 실패")
            return false
        }
        var error: NSDictionary?
        src.executeAndReturnError(&error)
        if let error {
            Logger.error("E-MAC-SYS-8002", "\(action.displayName) 실행 실패: \(error)")
            return false
        }
        Logger.info("SystemActionExecutor", "\(action.displayName) 실행")
        return true
    }
}
