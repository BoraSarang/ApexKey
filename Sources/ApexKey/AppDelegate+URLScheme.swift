//
//  AppDelegate+URLScheme.swift
//  ApexKey
//
//  apexkey:// URL scheme handling
//

import AppKit
import SwiftUI
import Combine

extension AppDelegate {
    // MARK: - URL Scheme 처리

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleOpenURL(url)
        }
    }

    func handleOpenURL(_ url: URL) {
        guard let store = self.store else { return }
        guard url.scheme == "apexkey" else { return }
        Logger.info("AppDelegate", "[URL] URL 수신: \(url.absoluteString)")

        if url.host == "run-binding",
           let bindingID = UUID(uuidString: url.lastPathComponent) {
            if let binding = store.bindings.first(where: { $0.id == bindingID }) {
                let frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                if ActionExecutor.shared.shouldExecute(binding, frontmostBundleID: frontBundle) {
                    ActionExecutor.shared.execute(binding)
                    Logger.info("AppDelegate", "[URL] binding 실행: \(bindingID)")
                }
            } else {
                Logger.error("E-MAC-URL-4001", "binding을 찾을 수 없음: \(bindingID)")
            }
        } else if url.host == "run-macro-by-name",
                  let name = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "name" })?.value {
            if let binding = store.bindings.first(where: { $0.title == name }) {
                let frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                if ActionExecutor.shared.shouldExecute(binding, frontmostBundleID: frontBundle) {
                    ActionExecutor.shared.execute(binding)
                    Logger.info("AppDelegate", "[URL] 매크로 이름으로 실행: \(name)")
                }
            } else {
                Logger.error("E-MAC-URL-4002", "매크로를 찾을 수 없음: \(name)")
            }
        } else {
            Logger.error("E-MAC-URL-4003", "알 수 없는 URL: \(url.absoluteString)")
        }
    }
}
