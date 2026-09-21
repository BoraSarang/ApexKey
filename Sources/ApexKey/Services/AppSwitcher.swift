import Foundation
import AppKit
import ApplicationServices

/// 앱 실행 / 포커스 / 토글 서비스
enum AppSwitcher {
    /// 앱이 실행 중인지
    static func isRunning(bundleID: String) -> Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains { $0.isFinishedLaunching }
    }

    /// 앱 실행 + 전면으로
    @discardableResult
    static func activate(bundleID: String, path: String? = nil, args: [String] = []) -> Bool {
        // URL 스킴은 번들과 무관하게 직접 open
        if bundleID.hasPrefix("apexkey-url:") {
            let raw = String(bundleID.dropFirst("apexkey-url:".count))
            if let url = URL(string: raw) {
                NSWorkspace.shared.open(url)
                Logger.info("AppSwitcher", "[LAUNCH] URL 스킴 실행: \(raw)")
                return true
            }
            Logger.error("E-MAC-APP-4002", "잘못된 URL 스킴: \(raw)")
            return false
        }
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first(where: { $0.isFinishedLaunching }) {
            // 인자가 있으면 새 프로세스로 전달 후 활성화
            if !args.isEmpty {
                launchWithArgs(bundleID: bundleID, path: path, args: args)
            }
            running.activate(options: [.activateAllWindows])
            // 이미 실행 중이면 윈도우를 앞으로
            raiseWindows(for: running.processIdentifier)
            return true
        }
        // 미실행 → 실행
        // 1) 명시 경로 → 2) LaunchServices 등록 정보(번들ID)에서 실행 URL 해석
        var resolvedURL: URL?
        if let path, FileManager.default.fileExists(atPath: path) {
            resolvedURL = URL(fileURLWithPath: path)
        } else if let registered = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            resolvedURL = registered
        }
        guard let resolvedURL else {
            Logger.error("E-MAC-APP-4001", "앱 경로/등록 정보 없음: \(bundleID)")
            return false
        }
        // 인자 전달 실행
        if !args.isEmpty {
            return launchWithArgs(bundleID: bundleID, path: resolvedURL.path, args: args)
        }
        if NSWorkspace.shared.open(resolvedURL) {
            // 잠시 대기 후 활성화
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                    app.activate(options: [.activateAllWindows])
                    app.activate(options: [.activateIgnoringOtherApps])
                }
            }
            return true
        } else {
            Logger.error("E-MAC-APP-4001", "앱 실행 실패: \(resolvedURL.path)")
            return false
        }
    }

    /// 실행/숨김 토글 (Thor 스타일)
    @discardableResult
    static func toggle(bundleID: String, path: String? = nil, args: [String] = []) -> Bool {
        // URL 스킴은 토글 개념 없이 실행만
        if bundleID.hasPrefix("apexkey-url:") {
            return activate(bundleID: bundleID)
        }
        if isRunning(bundleID: bundleID),
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            if app.isActive {
                Logger.info("AppSwitcher", "[LAUNCH] 전면이면 숨김: \(bundleID)")
                app.hide()
                return true
            } else {
                Logger.info("AppSwitcher", "[LAUNCH] 실행 중 → 활성화: \(bundleID)")
                if !args.isEmpty {
                    launchWithArgs(bundleID: bundleID, path: path, args: args)
                }
                app.activate(options: [.activateAllWindows])
                raiseWindows(for: app.processIdentifier)
                return true
            }
        }
        Logger.info("AppSwitcher", "[LAUNCH] 미실행 → 실행: \(bundleID)")
        return activate(bundleID: bundleID, path: path, args: args)
    }

    /// 구조화 설정으로 실행 (LaunchConfig 진입점)
    @discardableResult
    static func execute(config: LaunchConfig) -> Bool {
        let bundleID = config.bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let scheme = config.urlScheme.trimmingCharacters(in: .whitespacesAndNewlines)
        // URL 스킴 우선
        if !scheme.isEmpty {
            guard let url = URL(string: scheme) else {
                Logger.error("E-MAC-APP-4002", "잘못된 URL 스킴: \(scheme)")
                return false
            }
            NSWorkspace.shared.open(url)
            Logger.info("AppSwitcher", "[LAUNCH] URL 스킴 실행: \(scheme)")
            return true
        }
        guard !bundleID.isEmpty || !config.path.isEmpty else {
            Logger.error("E-MAC-APP-4001", "앱 미지정 — 번들ID 또는 경로 필요")
            return false
        }
        let effectiveBundleID = bundleID.isEmpty ? bundleIDFrom(path: config.path) : bundleID
        let path: String? = config.path.isEmpty ? nil : config.path
        let args = config.parsedArgs
        switch config.mode {
        case .toggle:
            return toggle(bundleID: effectiveBundleID, path: path, args: args)
        case .activate:
            if isRunning(bundleID: effectiveBundleID) {
                return activate(bundleID: effectiveBundleID, path: path, args: args)
            }
            return activate(bundleID: effectiveBundleID, path: path, args: args)
        case .launch:
            return activate(bundleID: effectiveBundleID, path: path, args: args)
        }
    }

    /// 인자 전달 실행 (NSWorkspace.Configuration)
    @discardableResult
    private static func launchWithArgs(bundleID: String, path: String?, args: [String]) -> Bool {
        var appURL: URL?
        if let path, FileManager.default.fileExists(atPath: path) {
            appURL = URL(fileURLWithPath: path)
        } else if !bundleID.isEmpty, let registered = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            appURL = registered
        }
        guard let appURL else {
            Logger.error("E-MAC-APP-4001", "앱 경로/등록 정보 없음 (인자 실행): \(bundleID)")
            return false
        }
        let conf = NSWorkspace.OpenConfiguration()
        conf.arguments = args
        conf.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: conf) { app, error in
            if let error {
                Logger.error("E-MAC-APP-4001", "인자 실행 실패: \(error.localizedDescription)")
            } else {
                Logger.info("AppSwitcher", "[LAUNCH] 인자 실행: \(appURL.lastPathComponent) \(args.joined(separator: " "))")
            }
        }
        return true
    }

    /// 경로에서 번들ID 역조회 (수동 추가 앱용)
    private static func bundleIDFrom(path: String) -> String {
        if let bundle = Bundle(url: URL(fileURLWithPath: path)), let id = bundle.bundleIdentifier {
            return id
        }
        return ""
    }

    /// 특정 앱의 모든 윈도우를 전면으로 올림 (AXUIElement)
    private static func raiseWindows(for pid: pid_t) {
        let axApp = AXUIElementCreateApplication(pid)
        var windows: CFTypeRef?
        AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windows)
        guard let windowsArray = windows as? [AXUIElement] else { return }
        for window in windowsArray {
            AXUIElementSetAttributeValue(window, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        }
    }
}
