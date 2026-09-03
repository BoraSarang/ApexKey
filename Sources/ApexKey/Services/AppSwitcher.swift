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
    static func activate(bundleID: String, path: String? = nil) -> Bool {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first(where: { $0.isFinishedLaunching }) {
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
    static func toggle(bundleID: String, path: String? = nil) -> Bool {
        if isRunning(bundleID: bundleID),
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            if app.isActive {
                Logger.info("AppSwitcher", "[LAUNCH] 전면이면 숨김: \(bundleID)")
                app.hide()
                return true
            } else {
                Logger.info("AppSwitcher", "[LAUNCH] 실행 중 → 활성화: \(bundleID)")
                app.activate(options: [.activateAllWindows])
                raiseWindows(for: app.processIdentifier)
                return true
            }
        }
        Logger.info("AppSwitcher", "[LAUNCH] 미실행 → 실행: \(bundleID)")
        return activate(bundleID: bundleID, path: path)
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
