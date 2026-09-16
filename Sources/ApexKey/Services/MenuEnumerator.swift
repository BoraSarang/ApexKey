import Foundation
import ApplicationServices
import AppKit

/// 타 앱의 메뉴바를 AXUIElement로 열거하는 서비스
final class MenuEnumerator {
    static let shared = MenuEnumerator()

    /// 실행 중인 앱의 번들ID로 메뉴를 열거
    /// - Returns: 루트 메뉴 항목 배열 (대략적인 메뉴바 항목)
    func enumerateMenuItems(bundleID: String) -> [MenuItem] {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first(where: { $0.isFinishedLaunching }) else {
            Logger.info("MenuEnumerator", "\(bundleID) 실행 중이 아님 — 메뉴 열거 불가")
            return []
        }
        Logger.info("MenuEnumerator", "[MENU] 열거 시작: \(bundleID)")
        let items = enumerateMenuItems(pid: app.processIdentifier)
        Logger.info("MenuEnumerator", "[MENU] 열거 완료: \(bundleID) → 메뉴바 \(items.count)개 메뉴")
        return items
    }

    /// PID로 메뉴바 열거
    func enumerateMenuItems(pid: pid_t) -> [MenuItem] {
        guard PermissionHelper.isAccessibilityTrusted else {
            Logger.error("E-MAC-MENU-3001", "Accessibility 권한 없음 (메뉴 열거 불가)")
            return []
        }

        let axApp = AXUIElementCreateApplication(pid)
        var menubarValue: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString, &menubarValue)
        guard status == .success, let menubar = menubarValue else {
            Logger.info("MenuEnumerator", "메뉴바 없음 (pid=\(pid), status=\(status.rawValue))")
            return []
        }
        // CFTypeRef → AXUIElement 확인은 타입ID 비교가 정석 (R-04)
        guard CFGetTypeID(menubar) == AXUIElementGetTypeID() else {
            Logger.error("E-MAC-MENU-3004", "메뉴바 타입 불일치 (pid=\(pid))")
            return []
        }
        // 타입 확인 후이므로 unsafeDowncast (런타임 체크 없는 확정 변환)
        return menus(in: unsafeDowncast(menubar, to: AXUIElement.self))
    }

    /// 특정 앱의 메뉴 항목에서 지정 키 조합(단축키)이 있는 항목만 추출
    /// - Returns: 단축키가 있는 메뉴 항목들 (재귀 포함)
    func shortcutItems(in items: [MenuItem]) -> [MenuItem] {
        var result: [MenuItem] = []
        for item in items {
            if item.isSubmenu {
                result.append(contentsOf: shortcutItems(in: item.children))
            } else if item.hasKeyEquivalent {
                result.append(item)
            }
        }
        return result
    }

    /// 서브메뉴 노드는 재귀 펼쳐 잎(실제 명령) 항목만 평면화 — 단축키 유무 무관.
    /// (글로벌 단축키 할당·HUD 표시는 단축키 없는 명령도 대상이므로 사용)
    func allItems(in items: [MenuItem]) -> [MenuItem] {
        var result: [MenuItem] = []
        for item in items {
            if item.isSubmenu {
                result.append(contentsOf: allItems(in: item.children))
            } else {
                result.append(item)
            }
        }
        return result
    }

    /// 서브메뉴 **부모 노드를 포함**해 깊이(depth)를 보존하면서 평탄화 — HUD 계층(indent) 표시용.
    /// 부모도 항목으로 남고, 자식은 depth+1로 들여쓰기되어 계층이 시각적으로 유지된다.
    /// 최상위 메뉴 노드(depth 0)는 메뉴 그룹 헤더로 이미 중복 표시되므로 생략하고,
    /// 그 아래 서브메뉴 부모부터(depth 1) 포함한다.
    func flattenedWithDepth(in items: [MenuItem], depth: Int = 0) -> [MenuItem] {
        var result: [MenuItem] = []
        for item in items {
            if depth == 0 {
                // 최상위 메뉴 노드 자체는 생략 — 서브메뉴 부모(및 잎)만 depth 1부터 포함
                if item.isSubmenu {
                    result.append(contentsOf: flattenedWithDepth(in: item.children, depth: 1))
                } else {
                    var deeper = item
                    deeper.depth = depth
                    result.append(deeper)
                }
            } else {
                var deeper = item
                deeper.depth = depth
                result.append(deeper)
                if item.isSubmenu {
                    result.append(contentsOf: flattenedWithDepth(in: item.children, depth: depth + 1))
                }
            }
        }
        return result
    }

    /// 메뉴 항목 실행 (글로벌 핫키로 트리거)
    /// 대상 앱을 전면으로 가져온 뒤, 저장된 경로(menuPath)를 따라
    /// System Events AppleScript 메뉴 클릭으로 실행한다.
    /// (AX 직접 press의 활성화 직후 transient 탐색 실패 — E-MAC-MENU-3002 — 를
    ///  회피하기 위해 AppleScript 계층으로 전환. 빈 AXMenu 레벨도 자동 처리됨)
    /// - Returns: 실행 결과 (성공인지 / 어느 단계가 실패했는지)
    @discardableResult
    func performAction(_ item: MenuItem, in bundleID: String) -> MenuActionResult {
        guard PermissionHelper.isAccessibilityTrusted else {
            Logger.error("E-MAC-MENU-3002", "Accessibility 권한 없음")
            return .noPermission
        }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first(where: { $0.isFinishedLaunching }) else {
            Logger.info("MenuEnumerator", "\(bundleID) 실행 중이 아님 — 메뉴 명령 취소: \(item.title)")
            return .appNotRunning
        }
        // System Events 메뉴 클릭은 대상 프로세스명(name)으로 식별한다.
        // localizedName이 곧 System Events가 보는 프로세스 이름(IINA 등)이다.
        let processName = app.localizedName ?? bundleID

        // 실행 경로: item.menuPath(최상위 메뉴부터) 없으면 title 단일 경로로 fallback
        // (빈 AXMenu 레벨은 AppleScript 계층에서 자동으로 처리되므로 명시할 필요 없음)
        var path = item.menuPath
        if path.isEmpty { path = [item.title] }
        // 서브메뉴 부모(실행 명령이 아닌 컨테이너)는 실행 대상이 아님 — 단순 보호
        if item.isSubmenu && path.count == 1 {
            Logger.info("MenuEnumerator", "서브메뉴 부모 — 실행 생략: \(item.title)")
            return .menuNotFound
        }
        Logger.info("MenuEnumerator", "메뉴 실행 경로: \(path.joined(separator: " > "))")

        // 대상 앱을 전면으로 활성화 후 메뉴바가 준비될 시간 대기 (System Events도 전면 앱 접근이 안정적)
        AppSwitcher.activate(bundleID: bundleID)
        Thread.sleep(forTimeInterval: 0.15)

        // System Events 클릭 스크립트 구성:
        //   tell process "P" to click menu item "마지막" of menu 1 of menu bar item "첫번째" of menu bar 1
        // 서브메뉴(3단계 이상)는 "menu 1 of menu item ... of" 체인으로 표현.
        // path.count == 1이면 경로가 단일 메뉴 항목뿐이라 서브메뉴 체인 루프는 생략한다.
        // (path.count >= 2일 때 path[1 ..< (count-1)]가 유효한 범위)
        var script = "tell application \"System Events\"\n"
        script += "  tell process \(appleScriptQuoted(processName))\n"
        script += "    click menu item \(appleScriptQuoted(path[path.count - 1]))"
        if path.count > 1 {
            for seg in path[1..<(path.count - 1)].reversed() {
                script += " of menu 1 of menu item \(appleScriptQuoted(seg))"
            }
        }
        script += " of menu 1 of menu bar item \(appleScriptQuoted(path[0])) of menu bar 1\n"
        script += "  end tell\n"
        script += "end tell"

        let result = runOSAScript(script)
        switch result {
        case .success:
            Logger.info("MenuEnumerator", "메뉴 실행: \(path.joined(separator: " > "))")
            return .success
        case .error(let message):
            Logger.error("E-MAC-MENU-3002", "메뉴 명령 실패(AppleScript): \(item.title) — \(message)")
            return .menuNotFound
        }
    }

    /// AppleScript 문자열 리터럴로 안전하게 감싼다 (따옴표·백슬래시 이스케이프)
    private func appleScriptQuoted(_ text: String) -> String {
        let escaped = text.replacingOccurrences(of: "\\", with: "\\\\")
                          .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private enum OSAScriptResult {
        case success
        case error(String)
    }

    /// osascript를 실행하고 성공/실패(표준오류 메시지)를 반환
    private func runOSAScript(_ script: String) -> OSAScriptResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .error("osascript 실행 실패: \(error.localizedDescription)")
        }
        if process.terminationStatus == 0 {
            return .success
        }
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        let message = String(data: errData, encoding: .utf8) ?? "status=\(process.terminationStatus)"
        return .error(message.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Private

    /// 메뉴바의 최상위 메뉴들(AXMenuBarItem)을 MenuItem으로 변환
    private func menus(in menubar: AXUIElement) -> [MenuItem] {
        var result: [MenuItem] = []
        for menu in children(of: menubar) {
            // 시스템 전역 Apple( ) 메뉴(이 Mac/시스템 설정/재시동/로그아웃 등)는 모든 앱 동일하므로 제외
            if elementTitle(of: menu) == "Apple" { continue }
            result.append(contentsOf: menuItems(from: menu, parentPath: []))
        }
        return result
    }

    /// 요소(및 하위 재귀)를 MenuItem 배열로 변환.
    /// - Parameter parentPath: 이 요소의 **부모까지**의 경로 (자신 title은 여기서 붙임)
    /// - Parameter depth: 이 요소의 계층 깊이 (최상위 메뉴 항목 0)
    ///
    /// 빈 title인 서브메뉴 컨테이너(AXMenu 등)는 실제 계층의 한 레벨이지만
    /// 앱마다 유무가 달라 경로가 불안정하고, 트리에 "(하위 메뉴)" 노드로 숨어
    /// 실제 항목이 안 보이게 된다. 따라서 빈 title 서브메뉴는 노드로 만들지 않고
    /// 그 자식들을 상위로 끌어올린다(flatten). menuPath는 빈 단계를 포함하지 않아
    /// 앱 간 구조 차이와 무관하게 일관된 경로를 만든다.
    /// (실행 탐색 child(named:)는 빈 AXMenu를 자동으로 파고들므로 호환된다.)
    private func menuItems(from element: AXUIElement, parentPath: [String], depth: Int = 0) -> [MenuItem] {
        let title = elementTitle(of: element)
        let ownPath = title.isEmpty ? parentPath : parentPath + [title]

        // 자식 재귀 — 빈 AXMenu 컨테이너도 그 안의 실질 항목까지 내려가 flatten
        var childItems: [MenuItem] = []
        for sub in children(of: element) {
            // 시스템 주입 Services 메뉴(제목 "서비스"/"Services")는 모든 앱 공통이고
            // 단축키 실행에 무의미하므로 통째로 제외한다.
            let childTitle = elementTitle(of: sub)
            if childTitle == "서비스" || childTitle == "Services" { continue }
            childItems.append(contentsOf: menuItems(from: sub, parentPath: ownPath, depth: depth + 1))
        }

        let combo = keyEquivalent(from: element, title: title)

        // 분리자: title·단축키 모두 비고 자식도 없음
        if title.isEmpty && combo.char.isEmpty && childItems.isEmpty {
            return [MenuItem(title: "─", isSeparator: true, menuPath: parentPath)]
        }
        // 빈 title 서브메뉴 컨테이너(AXMenu): 래퍼 노드 대신 자식만 상위로 끌어올림
        if title.isEmpty && !childItems.isEmpty {
            return childItems
        }
        return [
            MenuItem(
                title: title,
                commandChar: combo.char,
                commandModifiers: combo.modifiers,
                isSubmenu: !childItems.isEmpty,
                children: childItems,
                menuPath: ownPath,
                depth: depth
            )
        ]
    }

    /// 요소의 직접 자식(AXUIElement) 배열
    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let arr = value as? [AXUIElement] else { return [] }
        return arr
    }

    /// 요소의 title 읽기
    private func elementTitle(of element: AXUIElement) -> String {
        var titleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue)
        return titleValue as? String ?? ""
    }

    /// AX 메뉴 항목에서 키 등가물(Cmd+N 등) 읽기
    /// AX의 kAXMenuItemCmdModifiersAttribute는 Carbon flags(1<<8 cmd, 1<<9 shift…)를 반환하므로
    /// KeyboardUtil 상수와 맞춰 해석한다. cmdChar가 비어 있으면 title 표기(예: "열기 ⌘O")에서 fallback 파싱.
    private func keyEquivalent(from element: AXUIElement, title: String) -> (char: String, modifiers: UInt32) {
        var cmdChar: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXMenuItemCmdCharAttribute as CFString, &cmdChar)
        var cmdModifiers: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXMenuItemCmdModifiersAttribute as CFString, &cmdModifiers)

        // 1) AX가 직접 제공하는 키 조합 (NSNumber 안전 캐스팅)
        if let char = cmdChar as? String, !char.isEmpty {
            let raw = ((cmdModifiers as? NSNumber)?.uint32Value) ?? 0
            // kAXMenuItemCmdModifiersAttribute는 하위 4비트 인코딩:
            //   bit0 = ⇧(shift), bit1 = ⌥(option), bit2 = ⌃(control), bit3 = "⌘ 없음"(역전)
            // 이를 Carbon flags(KeyboardUtil.*Mask)로 변환한다.
            var mods: UInt32 = 0
            if raw & 0x08 == 0 { mods |= KeyboardUtil.cmdMask }      // bit3 꺼짐 → ⌘ 있음
            if raw & 0x01 != 0 { mods |= KeyboardUtil.shiftMask }    // bit0 ⇧
            if raw & 0x02 != 0 { mods |= KeyboardUtil.optionMask }   // bit1 ⌥
            if raw & 0x04 != 0 { mods |= KeyboardUtil.controlMask }  // bit2 ⌃
            return (char, mods)
        }

        // 2) title 표기 fallback (예: "새 창 ⌘⇧N", "다음 ⌥F2") 마지막 토큰 파싱
        return Self.parseKeyEquivalent(in: title)
    }

    /// title 문자열 끝의 단축키 표기(⌘⇧N, F2, ⌘, 등)를 Carbon flags로 파싱
    static func parseKeyEquivalent(in title: String) -> (char: String, modifiers: UInt32) {
        // 마지막 스페이스 뒤 토큰이 단축키 패턴인지 확인
        guard let lastToken = title.split(separator: " ").last else { return ("", 0) }
        let token = String(lastToken)
        guard !token.isEmpty else { return ("", 0) }
        var mods: UInt32 = 0
        var remainder = Substring(token)
        // 기호형 수식키 (⌘⇧⌥⌃) 소비
        var consumedSymbol: [String] = []
        for sym in ["⌘", "⇧", "⌥", "⌃"] {
            if remainder.hasPrefix(sym) {
                consumedSymbol.append(sym)
                remainder = remainder.dropFirst(sym.count)
            }
        }
        // 남은 부분이 문자/번호/F1 ~ F12 등이면 유효한 키
        let keyPart = String(remainder)
        // 단축키는 보통 수식키(⌘⇧⌥⌃) 0개 이상 + (문자 1개 / F키 / 특수키) 형태.
        // 평범한 메뉴명 마지막 토큰(한글·여러 글자·구두점)을 단축키로 오인하지 않도록 검증한다.
        let isValidKey: Bool = keyPart.range(of: "^F\\d+$", options: .regularExpression) != nil || keyPart.count == 1
        if isValidKey {
            for sym in consumedSymbol {
                switch sym {
                case "⌘": mods |= KeyboardUtil.cmdMask
                case "⇧": mods |= KeyboardUtil.shiftMask
                case "⌥": mods |= KeyboardUtil.optionMask
                case "⌃": mods |= KeyboardUtil.controlMask
                default: break
                }
            }
            return (keyPart, mods)
        }
        // 평범한 텍스트(단축키 아님) → 단축키 없음. 수식키만 있고 키 문자가 없는 경우도 무시.
        return ("", 0)
    }
}

/// AX 메뉴 명령 실행 결과
enum MenuActionResult: Equatable {
    case success
    case appNotRunning
    case noPermission
    case menuNotFound

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var description: String {
        switch self {
        case .success: return "menu.action.status_success".localized
        case .appNotRunning: return "menu.action.status_app_not_running".localized
        case .noPermission: return "menu.action.status_no_permission".localized
        case .menuNotFound: return "menu.action.status_menu_not_found".localized
        }
    }
}
