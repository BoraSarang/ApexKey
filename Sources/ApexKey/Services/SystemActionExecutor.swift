import Foundation
import AppKit

/// 시스템 동작(잠금/음소거/다크모드 등) 실행 서비스
enum SystemActionType: String, Codable, CaseIterable, Identifiable {
    case lock
    case mute
    case darkMode

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lock:     return "화면 잠금"
        case .mute:     return "음소거 토글"
        case .darkMode: return "다크 모드 토글"
        }
    }

    var systemImage: String {
        switch self {
        case .lock:     return "lock"
        case .mute:     return "speaker.slash"
        case .darkMode: return "moon"
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
        .darkMode: "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"
    ]

    /// 시스템 동작 실행. 성공 여부 반환.
    @discardableResult
    static func execute(_ type: SystemActionType) -> Bool {
        if type == .mute {
            // AppleScript 없는 순수 볼륨 토글
            return toggleMute()
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
