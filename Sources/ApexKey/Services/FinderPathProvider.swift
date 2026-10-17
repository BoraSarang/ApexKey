import AppKit
import ApplicationServices

/// Finder에서 "지금 열어야 할 폴더"를 접근성(AX)으로 읽는다 (T-195).
///
/// **왜 AppleScript가 아닌가**: T-194에서 `Finder`에 AppleScript를 보내 화면 크기를
/// 얻으려다 Automation(TCC Apple Events) 권한이 없어 실패했다. ApexKey는 접근성 권한을
/// 이미 필수로 받으므로 AX 경로는 **추가 권한 없이** 같은 권한 안에서 동작한다.
///
/// 실패는 `nil`로 돌려주고 호출부가 사용자 문구로 표면화한다 (무음 실패 금지).
enum FinderPathProvider {
    static let finderBundleID = "com.apple.finder"

    /// AX 순회 상한. Finder 창 서브트리는 폴더를 펼치면 수천 노드가 된다 —
    /// 상한이 없으면 실행큐를 오래 점유한다.
    private static let maxNodes = 3000
    private static let maxDepth = 12

    /// 열 폴더 — **선택 우선, 없으면 현재 창 폴더**.
    /// - Returns: 열 폴더 URL. 권한이 없거나 Finder 창을 못 찾으면 nil.
    static func resolveFolderURL() -> URL? {
        guard PermissionHelper.isAccessibilityTrusted else {
            Logger.error("E-MAC-TERM-8101", "Finder 폴더를 읽을 접근성 권한이 없습니다")
            return nil
        }
        guard let finder = NSRunningApplication
            .runningApplications(withBundleIdentifier: finderBundleID).first,
            let window = frontWindow(of: AXUIElementCreateApplication(finder.processIdentifier)) else {
            Logger.error("E-MAC-TERM-8102", "Finder 전면 창을 찾을 수 없습니다")
            return nil
        }

        let selection = selectedURLs(in: window)
        let folder = resolveFolder(selection: selection, currentFolder: currentFolder(of: window))
        if let folder {
            Logger.info("FEATURE", "터미널에서 열기 대상: \(folder.path) (선택 \(selection.count)건)")
        } else {
            Logger.error("E-MAC-TERM-8102", "Finder에서 폴더를 찾을 수 없습니다 (선택 \(selection.count)건)")
        }
        return folder
    }

    // MARK: - 순수 로직 (테스트 대상)

    /// 선택 우선 → 현재 폴더 규칙.
    ///
    /// - 선택에 **폴더가 있으면 그 폴더**(첫 번째). 파일만 골랐으면 그 파일의 **상위 폴더**.
    /// - 선택이 없으면 현재 창이 보고 있는 폴더.
    static func resolveFolder(
        selection: [URL],
        currentFolder: URL?,
        isDirectory: (URL) -> Bool = FinderPathProvider.defaultIsDirectory
    ) -> URL? {
        if let directory = selection.first(where: isDirectory) { return directory }
        if let first = selection.first { return first.deletingLastPathComponent() }
        return currentFolder
    }

    static func defaultIsDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    // MARK: - AX 읽기

    private static func frontWindow(of app: AXUIElement) -> AXUIElement? {
        if let focused = elementAttribute(app, kAXFocusedWindowAttribute) { return focused }
        // 창이 여러 개면 AXWindows의 첫 원소가 전면이다
        return arrayAttribute(app, kAXWindowsAttribute as String)?.first
    }

    /// 창이 보고 있는 폴더 (`AXDocument` = `file:///...`)
    private static func currentFolder(of window: AXUIElement) -> URL? {
        guard let document = stringAttribute(window, "AXDocument"),
              let url = URL(string: document), url.isFileURL else { return nil }
        return url
    }

    /// 창 안에서 선택된 항목들의 파일 URL. 선택이 없으면 빈 배열.
    private static func selectedURLs(in window: AXUIElement) -> [URL] {
        var found: [URL] = []
        var visited = 0

        func walk(_ element: AXUIElement, depth: Int) {
            guard found.isEmpty, visited < maxNodes, depth <= maxDepth else { return }
            visited += 1
            // 리스트/아이콘 보기 = AXSelectedChildren, 개요 보기 = AXSelectedRows
            for attribute in ["AXSelectedChildren", "AXSelectedRows"] {
                guard let selected = arrayAttribute(element, attribute), !selected.isEmpty else { continue }
                found = selected.compactMap { itemURL(of: $0) }
                if !found.isEmpty { return }
            }
            for child in arrayAttribute(element, kAXChildrenAttribute as String) ?? [] {
                walk(child, depth: depth + 1)
                if !found.isEmpty { return }
            }
        }

        walk(window, depth: 0)
        return found
    }

    private static func itemURL(of element: AXUIElement) -> URL? {
        if let raw = stringAttribute(element, "AXURL"), let url = URL(string: raw), url.isFileURL {
            return url
        }
        // 일부 보기(스마트 폴더·검색 결과)는 AXURL을 노출하지 않고 AXDocument만 준다
        if let raw = stringAttribute(element, "AXDocument"), let url = URL(string: raw), url.isFileURL {
            return url
        }
        return nil
    }

    // MARK: - AX 프리미티브

    private static func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let text = value as? String, !text.isEmpty else { return nil }
        return text
    }

    private static func elementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let raw = value, CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        return (raw as! AXUIElement)
    }

    private static func arrayAttribute(_ element: AXUIElement, _ attribute: String) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let list = value as? [AXUIElement] else { return nil }
        return list
    }
}
