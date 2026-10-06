import Foundation
import ApplicationServices
import AppKit

/// 메뉴바 아이콘(상태 아이템) 열거 + 클릭 (M-03)
///
/// **게이트 판정** (2026-10-06 실측):
/// - 시스템 아이콘(Wi-Fi·배터리·제어센터·시계): `MenuBarAgent.AXExtrasMenuBar → AXGroup → AXMenuBarItem`
///   으로 열거 가능. 이름은 `AXDescription`에 있다(title은 없음). `AXPress`/`AXShowMenu` 지원.
/// - 서드파티 아이콘: 각 앱 프로세스의 `AXExtrasMenuBar` 직속 자식으로 열거 가능.
/// - ControlCenter 프로세스 자체는 extras 값을 주지 않는다 — 시스템 아이콘은 MenuBarAgent 경로로 커버.
/// - 썸네일: AX 이미지가 없으므로 앱 아이콘(`NSRunningApplication.icon`)으로 폴백
///   (MenuDart는 화면 기록 권한으로 실제 아이콘을 뜬다 — 그 권한 플로우는 후속 과제).
/// 클릭 후 메뉴는 원래 위치(메뉴바 아래)에 뜨므로, 포인터만 아이콘 x좌표로 워프한다.
final class MenuBarIconEnumerator {
    static let shared = MenuBarIconEnumerator()

    /// 시스템 아이콘 호스트 프로세스
    static let menuBarAgentBundleID = "com.apple.MenuBarAgent"

    /// 그리드 표시용 아이콘 1건 (AX 요소 포함 — 클릭에 사용)
    struct IconItem {
        /// 표시 이름 (AXDescription 또는 앱 이름)
        var title: String
        /// 소유 앱 번들ID (썸네일 폴백용, 없으면 시스템 아이콘)
        var bundleID: String?
        var pid: pid_t
        /// 클릭 대상 AX 요소
        var element: AXUIElement
        /// 메뉴바상 x 위치 (정렬용, 없으면 뒤로)
        var positionX: CGFloat?
        /// 우클릭 대체 액션 보유 여부
        var hasShowMenu: Bool

        /// 시스템 아이콘인가 (MenuBarAgent 경유)
        var isSystemIcon: Bool { bundleID == MenuBarIconEnumerator.menuBarAgentBundleID }
    }

    /// 클릭 결과
    enum ClickResult: Equatable {
        case success
        case noPermission
        case actionFailed

        var isSuccess: Bool { self == .success }

        /// 실패 시 토스트 문구 (M-05 패턴 — 성공은 nil)
        var toastMessage: String? {
            switch self {
            case .success: return nil
            case .noPermission: return "menubar.icons.click_no_permission".localized
            case .actionFailed: return "menubar.icons.click_failed".localized
            }
        }
    }

    /// 시스템 아이콘 설명 → SF Symbol 매핑 (순수 함수).
    /// AX에 이미지가 없으므로 썸네일은 앱 아이콘, 시스템 아이콘은 아래 기호로 폴백한다.
    static func systemSymbolName(forDescription desc: String) -> String {
        let lower = desc.lowercased()
        if lower.contains("wi-fi") || lower.contains("wifi") || lower.contains("wireless") { return "wifi" }
        if lower.contains("battery") || lower.contains("배터리") { return "battery.100" }
        if lower.contains("control center") || lower.contains("제어 센터") || lower.contains("제어센터") { return "switch.2" }
        if lower.contains("clock") || lower.contains("시계") || lower.contains("time") { return "clock" }
        if lower.contains("bluetooth") { return "bluetooth" }
        if lower.contains("sound") || lower.contains("volume") || lower.contains("사운드") || lower.contains("음량") { return "speaker.wave.2" }
        if lower.contains("spotlight") || lower.contains("siri") { return "magnifyingglass" }
        return "circle.grid.2x2"
    }

    /// 그리드 썸네일 — 소유 앱 아이콘 우선, 시스템 아이콘은 SF Symbol.
    func thumbnail(for item: IconItem) -> NSImage? {
        if let bundleID = item.bundleID, bundleID != Self.menuBarAgentBundleID,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            if let icon = app.icon, icon.size.width > 0 { return icon }
        }
        return NSImage(systemSymbolName: Self.systemSymbolName(forDescription: item.title),
                       accessibilityDescription: item.title)
    }

    // MARK: - 열거

    /// 모든 메뉴바 아이콘. 권한 없으면 [] (조용 실패 — 호출부가 안내).
    /// 메인 스레드 호출용 동기 버전 (테스트·소규모 갱신). UI 진입은 enumerateAsync를 쓸 것.
    func enumerate() -> [IconItem] {
        guard PermissionHelper.isAccessibilityTrusted else { return [] }
        var items: [IconItem] = []
        items.append(contentsOf: systemIcons())
        items.append(contentsOf: thirdPartyIcons())
        return Self.sortIcons(items)
    }

    /// 비동기 전수 열거 (M-03 성능 수정) — Safari WebContent 같은 프로세스는 AX IPC가
    /// 1.5초씩 멈추므로(실측) 동기 호출하면 핫키가 "일주일" 걸린다. 앱별로 병렬 조회한다.
    /// AXUIElement 호출은 스레드 안전하므로 백그라운드에서実行, 정렬만 마지막에.
    /// `.prohibited` 프로세스(44개 중 extras 보유 0건 실측)는 건너뛴다 — MenuBarAgent만 예외.
    func enumerateAsync() async -> [IconItem] {
        guard PermissionHelper.isAccessibilityTrusted else { return [] }
        let system = systemIcons()
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy != .prohibited || $0.bundleIdentifier == Self.menuBarAgentBundleID
        }
        let third = await withTaskGroup(of: [IconItem].self) { group in
            for app in apps {
                group.addTask { [weak self] in
                    guard let self, let bundleID = app.bundleIdentifier,
                          bundleID != Self.menuBarAgentBundleID,
                          let bar = self.extrasMenuBar(of: AXUIElementCreateApplication(app.processIdentifier)) else { return [] }
                    return self.thirdPartyItems(in: bar, app: app, bundleID: bundleID)
                }
            }
            var merged: [IconItem] = []
            for await part in group { merged.append(contentsOf: part) }
            return merged
        }
        let items = system + third
        storeCache(items)
        return Self.sortIcons(items)
    }

    /// 최근 열거 캐시 — stale-while-revalidate: TTL이 지나도 낡은 목록을 즉시 보여주고
    /// 뒤에서 갱신한다. TTL 만료 때마다 수 초씩 기다리게 하지 않기 위함.
    private let cacheLock = NSLock()
    private var cache: (at: Date, items: [IconItem])?
    static let cacheTTL: TimeInterval = 30

    /// 신선한 캐시 (TTL 이내). 즉시 표시용.
    func cachedIcons() -> [IconItem]? {
        cacheLock.lock(); defer { cacheLock.unlock() }
        guard let cache, Date().timeIntervalSince(cache.at) < Self.cacheTTL else { return nil }
        return cache.items
    }

    /// 낡은 캐시 (TTL 무관). 갱신 중 즉시 표시용 — 없으면 nil.
    func staleIcons() -> [IconItem]? {
        cacheLock.lock(); defer { cacheLock.unlock() }
        guard let cache, !cache.items.isEmpty else { return nil }
        return cache.items
    }

    /// 캐시가 낡았는가 (없거나 TTL 경과)
    func isCacheStale() -> Bool {
        cacheLock.lock(); defer { cacheLock.unlock() }
        guard let cache else { return true }
        return Date().timeIntervalSince(cache.at) >= Self.cacheTTL
    }

    /// 앱 실행/종료 시 호출 — 다음 열기에 새로고침되게 무효화만 한다 (조회는 그때).
    func invalidateCache() {
        cacheLock.lock(); defer { cacheLock.unlock() }
        cache = nil
    }

    private func storeCache(_ items: [IconItem]) {
        cacheLock.lock(); defer { cacheLock.unlock() }
        cache = (Date(), items)
    }

    /// 앱 실행 직후 백그라운드 예열 — 첫 ⌥⌘]가 캐시 히트로 즉시 뜨게 한다.
    func prewarm() {
        Task.detached(priority: .background) { [weak self] in
            _ = await self?.enumerateAsync()
        }
    }

    /// 정렬 정책 (순수 함수 — 테스트 고정): 시스템 아이콘(메뉴바 순서) 먼저, 서드파티는 x좌표 순.
    static func sortIcons(_ items: [IconItem]) -> [IconItem] {
        items.sorted {
            if $0.isSystemIcon != $1.isSystemIcon { return $0.isSystemIcon }
            return ($0.positionX ?? .greatestFiniteMagnitude) < ($1.positionX ?? .greatestFiniteMagnitude)
        }
    }

    /// MenuBarAgent 산하 시스템 아이콘 (Wi-Fi·배터리·제어센터·시계 등)
    private func systemIcons() -> [IconItem] {
        guard let agent = NSRunningApplication.runningApplications(withBundleIdentifier: Self.menuBarAgentBundleID).first else { return [] }
        return groups(in: AXUIElementCreateApplication(agent.processIdentifier)).flatMap { children(of: $0) }.compactMap { element in
            guard role(of: element) == "AXMenuBarItem" else { return nil }
            let name = stringAttribute(element, kAXDescriptionAttribute as String)
                ?? stringAttribute(element, kAXTitleAttribute as String)
                ?? ""
            guard !name.isEmpty else { return nil }
            return IconItem(title: name, bundleID: Self.menuBarAgentBundleID, pid: agent.processIdentifier,
                            element: element, positionX: position(of: element)?.x, hasShowMenu: hasAction(element, "AXShowMenu"))
        }
    }

    /// 서드파티 앱 상태 아이템 (자사 포함 — MenuDart 그리드도 자사 포함)
    private func thirdPartyIcons() -> [IconItem] {
        var items: [IconItem] = []
        for app in NSWorkspace.shared.runningApplications {
            guard let bundleID = app.bundleIdentifier,
                  bundleID != Self.menuBarAgentBundleID else { continue }
            let bar = AXUIElementCreateApplication(app.processIdentifier)
            guard let extras = extrasMenuBar(of: bar) else { continue }
            items.append(contentsOf: thirdPartyItems(in: extras, app: app, bundleID: bundleID))
        }
        return items
    }

    /// 한 앱의 extras 직속 AXMenuBarItem 목록 (서드파티는 그룹 래퍼 없음)
    private func thirdPartyItems(in extras: AXUIElement, app: NSRunningApplication, bundleID: String) -> [IconItem] {
        children(of: extras).compactMap { element in
            // 서드파티는 직속 AXMenuBarItem (그룹 래퍼 없음)
            guard role(of: element) == "AXMenuBarItem" else { return nil }
            let name = stringAttribute(element, kAXDescriptionAttribute as String)
                ?? stringAttribute(element, kAXTitleAttribute as String)
                ?? app.localizedName ?? bundleID
            return IconItem(title: name, bundleID: bundleID, pid: app.processIdentifier,
                            element: element, positionX: position(of: element)?.x,
                            hasShowMenu: hasAction(element, "AXShowMenu"))
        }
    }

    // MARK: - 클릭

    /// 좌클릭(AXPress) / 우클릭(AXShowMenu → 없으면 CG 우클릭 이벤트).
    /// 성공 시 포인터를 아이콘 메뉴 위치(메뉴바 아래)로 워프한다 (M-03 포인터 비행).
    func click(_ item: IconItem, rightClick: Bool) -> ClickResult {
        guard PermissionHelper.isAccessibilityTrusted else { return .noPermission }
        let ok: Bool
        if rightClick {
            if item.hasShowMenu {
                ok = AXUIElementPerformAction(item.element, "AXShowMenu" as CFString) == .success
            } else if let pos = position(of: item.element) {
                ok = postRightClick(at: pos)
            } else {
                ok = false
            }
        } else {
            ok = AXUIElementPerformAction(item.element, kAXPressAction as CFString) == .success
        }
        guard ok else { return .actionFailed }
        warpPointerToMenu(near: item)
        return .success
    }

    /// 클릭한 아이콘 아래로 포인터 이동 — 메뉴가 열리는 위치로 데려간다.
    private func warpPointerToMenu(near item: IconItem) {
        guard let pos = position(of: item.element),
              let screen = NSScreen.screens.first(where: { $0.frame.contains(pos) }) ?? NSScreen.main else { return }
        // 메뉴바 아래(visible 상단 + 여유)로 워프. CG 좌표는 좌상단 원점이므로 변환.
        let targetX = min(max(pos.x, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - 8)
        let cgY = screen.frame.maxY - (screen.visibleFrame.maxY + 20)
        CGWarpMouseCursorPosition(CGPoint(x: targetX, y: max(cgY, 0)))
    }

    /// AX 위치에 CG 우클릭 이벤트 (AXShowMenu 없는 앱용 폴백)
    private func postRightClick(at pos: CGPoint) -> Bool {
        guard let eventDown = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: pos, mouseButton: .right),
              let eventUp = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: pos, mouseButton: .right) else { return false }
        eventDown.post(tap: .cghidEventTap)
        eventUp.post(tap: .cghidEventTap)
        return true
    }

    // MARK: - AX helpers

    private func extrasMenuBar(of app: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, "AXExtrasMenuBar" as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    /// MenuBarAgent extras의 AXGroup 래퍼들 (시스템 아이콘은 그룹 안에 한 단계 더 들어 있다)
    private func groups(in app: AXUIElement) -> [AXUIElement] {
        guard let extras = extrasMenuBar(of: app) else { return [] }
        let kids = children(of: extras)
        // 그룹 래퍼가 있으면 그 안을, 없으면 직속 자식을 쓴다
        let groups = kids.filter { role(of: $0) == "AXGroup" }
        return groups.isEmpty ? kids : groups
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let arr = value as? [AXUIElement] else { return [] }
        return arr
    }

    private func role(of element: AXUIElement) -> String {
        stringAttribute(element, kAXRoleAttribute as String) ?? ""
    }

    private func stringAttribute(_ element: AXUIElement, _ name: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let str = value as? String, !str.isEmpty else { return nil }
        return str
    }

    private func position(of element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value) == .success,
              let axValue = value, CFGetTypeID(axValue) == AXValueGetTypeID() else { return nil }
        let ax = unsafeDowncast(axValue, to: AXValue.self)
        var point = CGPoint.zero
        guard AXValueGetValue(ax, .cgPoint, &point) else { return nil }
        return point
    }

    private func hasAction(_ element: AXUIElement, _ action: String) -> Bool {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success,
              let names = names as? [String] else { return false }
        return names.contains(action)
    }
}
