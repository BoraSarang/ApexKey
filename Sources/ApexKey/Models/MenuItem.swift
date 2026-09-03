import Foundation

/// 타 앱의 메뉴 항목 하나 (AXUIElement로 열거한 결과)
struct MenuItem: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var commandChar: String      // Cmd+N 의 N
    var commandModifiers: UInt32 // Carbon modifier flags
    var isSeparator: Bool
    var isSubmenu: Bool
    var children: [MenuItem]
    /// 최상위 메뉴 title부터 이 항목까지의 경로 (예: ["파일", "새 창"]) — 실행 시 메뉴를 경로대로 열기 위함
    var menuPath: [String]
    /// 메뉴 계층 깊이 (최상위 메뉴 항목 0, 서브메뉴 자식은 1, 그 아래 2...) — HUD 들여쓰기 표시용
    var depth: Int

    init(
        title: String,
        commandChar: String = "",
        commandModifiers: UInt32 = 0,
        isSeparator: Bool = false,
        isSubmenu: Bool = false,
        children: [MenuItem] = [],
        menuPath: [String] = [],
        depth: Int = 0
    ) {
        self.title = title
        self.commandChar = commandChar
        self.commandModifiers = commandModifiers
        self.isSeparator = isSeparator
        self.isSubmenu = isSubmenu
        self.children = children
        self.menuPath = menuPath
        self.depth = depth
    }

    /// 실제 키 조합(단축키)이 있는 메뉴 항목인가
    var hasKeyEquivalent: Bool { !commandChar.isEmpty }

    /// 표시용 단축키 문자열 (예: "⌘N")
    /// commandModifiers는 AX가 주는 Carbon flags(1<<8 cmd / 1<<9 shift / 1<<11 option / 1<<12 control) 기준
    var keyEquivalentDisplay: String {
        guard hasKeyEquivalent else { return "" }
        var parts: [String] = []
        if commandModifiers & KeyboardUtil.cmdMask != 0 { parts.append("⌘") }
        if commandModifiers & KeyboardUtil.shiftMask != 0 { parts.append("⇧") }
        if commandModifiers & KeyboardUtil.optionMask != 0 { parts.append("⌥") }
        if commandModifiers & KeyboardUtil.controlMask != 0 { parts.append("⌃") }
        parts.append(commandChar.uppercased())
        return parts.joined()
    }
}
