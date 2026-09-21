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
    /// 기본 AppleScript (8종) — 수정분은 UserDefaults 오버라이드로 저장되어 재시작 후에도 유지된다.
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
        .finderRestart: "do shell script \"killall Finder\""
    ]

    /// Android Remote Mirror (scrcpy) — 외부 스크립트 파일이 단일 소스.
    /// 파일 수정이 앱에 즉시 반영된다 (재빌드 불필요).
    static let androidMirrorScriptPath =
        "/Users/lee/Documents/AGENTS/development/scripts/scrcpy_run.sh"

    // MARK: - 스크립트 조회/저장 (시스템 탭 편집 UI용)

    /// 파일 기반 항목인가 (androidMirror만 해당 — 나머지는 AppleScript 내장).
    static func isFileBacked(_ type: SystemActionType) -> Bool {
        type == .androidMirror
    }

    /// 편집 UI에 표시할 스크립트 언어 라벨.
    static func scriptLanguage(_ type: SystemActionType) -> String {
        type == .androidMirror ? "Shell (bash)" : "AppleScript"
    }

    private static func overrideKey(for type: SystemActionType) -> String {
        "SystemScriptOverride.\(type.rawValue)"
    }

    /// 현재 스크립트 소스 — 동작 탭의 단계 target처럼 보기/편집/테스트의 기준.
    /// - androidMirror: 외부 .sh 파일 내용 (없으면 빈 문자열)
    /// - 그 외: UserDefaults 수정분, 없으면 기본 AppleScript
    static func scriptSource(for type: SystemActionType) -> String {
        if type == .androidMirror {
            return (try? String(contentsOfFile: androidMirrorScriptPath, encoding: .utf8)) ?? ""
        }
        if let override = UserDefaults.standard.string(forKey: overrideKey(for: type)) {
            return override
        }
        return defaultAppleScripts[type] ?? ""
    }

    /// 기본 스크립트 (되돌리기 기준). 파일 기반은 디스크 현재 내용.
    static func defaultScriptSource(for type: SystemActionType) -> String {
        if type == .androidMirror {
            return (try? String(contentsOfFile: androidMirrorScriptPath, encoding: .utf8)) ?? ""
        }
        return defaultAppleScripts[type] ?? ""
    }

    /// 사용자 수정분이 있는가 (AppleScript 8종만 해당).
    static func hasCustomScript(for type: SystemActionType) -> Bool {
        guard !isFileBacked(type) else { return false }
        return UserDefaults.standard.string(forKey: overrideKey(for: type)) != nil
    }

    /// 스크립트 저장 — 동작 탭의 단계 저장처럼 즉시 실행에 반영된다.
    /// - androidMirror: 외부 .sh 파일에 직접 기록
    /// - 그 외: UserDefaults 오버라이드로 저장
    /// - returns: 성공 여부
    @discardableResult
    static func saveScript(_ source: String, for type: SystemActionType) -> Bool {
        if type == .androidMirror {
            do {
                try source.write(toFile: androidMirrorScriptPath, atomically: true, encoding: .utf8)
                Logger.info("SystemActionExecutor", "Android 미러 스크립트 파일 저장 (\(source.count)자): \(androidMirrorScriptPath)")
                return true
            } catch {
                Logger.error("E-MAC-SYS-8004", "미러 스크립트 파일 저장 실패: \(error.localizedDescription)")
                return false
            }
        }
        UserDefaults.standard.set(source, forKey: overrideKey(for: type))
        Logger.info("SystemActionExecutor", "\(type.displayName) 스크립트 수정 저장 (\(source.count)자)")
        return true
    }

    /// 수정분을 버리고 기본으로 되돌린다 (AppleScript 8종만 해당).
    static func resetScript(for type: SystemActionType) {
        guard !isFileBacked(type) else { return }
        UserDefaults.standard.removeObject(forKey: overrideKey(for: type))
        Logger.info("SystemActionExecutor", "\(type.displayName) 스크립트 기본값으로 복원")
    }

    /// 테스트 실행 상세 결과 — 동작 탭 하단 테스트 푸터(StepTestFooter)와 같은 형태.
    static func runTestDetailed(_ type: SystemActionType, source: String? = nil)
    -> (success: Bool, output: String, errorOutput: String, exitCode: Int32) {
        if type == .androidMirror {
            // 미리보기용 임시 소스가 있으면 파일 대신 /tmp 복사본으로 실행해
            // 저장 전 테스트가 디스크 파일을 오염시키지 않게 한다.
            if let source {
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent("apexkey-mirror-test-\(UUID().uuidString).sh").path
                do {
                    try source.write(toFile: tmp, atomically: true, encoding: .utf8)
                    let r = ActionExecutor.shared.runScriptFileResult(tmp)
                    try? FileManager.default.removeItem(atPath: tmp)
                    return (r.success, r.output, r.errorOutput, r.exitCode)
                } catch {
                    return (false, "", error.localizedDescription, -1)
                }
            }
            let r = ActionExecutor.shared.runScriptFileResult(androidMirrorScriptPath)
            return (r.success, r.output, r.errorOutput, r.exitCode)
        }
        let script = source ?? scriptSource(for: type)
        let r = ScriptExecutor.runAppleScript(script)
        return (r.success, r.output, r.errorOutput, r.success ? 0 : 1)
    }

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
        let script = scriptSource(for: type)
        guard !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return runAppleScript(script, action: type)
    }

    private static func toggleMute() -> Bool {
        let source = scriptSource(for: .mute)
        guard let src = NSAppleScript(source: source) else {
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
