import Foundation

// MARK: - ShortcutStep 확장

/// 단축어(동작)를 구성하는 하나의 단계
/// 실행 시 임시 HotKeyBinding으로 변환해 기존 ActionExecutor 로직을 재사용한다.
struct ShortcutStep: Identifiable, Codable, Hashable {
    var id: UUID
    var type: ActionType
    /// 대상 (번들ID / 파일 경로 / URL / 스크립트 명령 / 키코드 나열 / 좌표 등)
    var target: String
    /// 표시용 제목 (메뉴 명령·스크립트 등에서 사용)
    var title: String
    /// 메뉴 명령 실행 경로. 비어 있으면 title 기반 검색 fallback.
    var menuPath: [String]
    /// 앱이 활성화된 동안에만 실행 여부
    var onlyWhenAppActive: Bool
    
    // === iOS Shortcuts 확장 필드 ===
    
    /// 변수 설정 (이 단계가 설정할 변수들)
    var outputVariables: [Variable]?
    /// 각 액션의 상세 설정 (JSON 인코딩)
    var actionParameters: Data?
    /// 분기 설정 (If 액션용)
    var ifBranch: IfBranch?
    /// 반복 설정 (Repeat 액션용)
    var repeatLoop: RepeatLoop?
    /// Choose From Menu 설정
    var chooseFromMenu: ChooseFromMenu?
    /// Use Model 설정 (AI 액션용)
    var useModel: UseModelStep?
    /// Writing Tool 설정
    var writingTool: WritingToolStep?
    /// Image Playground 설정
    var imagePlayground: ImagePlaygroundStep?
    /// 단계 스킵 여부 (설정에서 토글)
    var isSkipped: Bool
    /// 주석/메모 (단계별 설명)
    var note: String?
    /// Magic Variable 토큰 (단계 간 데이터 흐름 연결)
    var magicVariableTokens: [String]?

    init(
        id: UUID = UUID(),
        type: ActionType,
        target: String,
        title: String = "",
        menuPath: [String] = [],
        onlyWhenAppActive: Bool = false,
        outputVariables: [Variable]? = nil,
        actionParameters: Data? = nil,
        ifBranch: IfBranch? = nil,
        repeatLoop: RepeatLoop? = nil,
        chooseFromMenu: ChooseFromMenu? = nil,
        useModel: UseModelStep? = nil,
        writingTool: WritingToolStep? = nil,
        imagePlayground: ImagePlaygroundStep? = nil,
        isSkipped: Bool = false,
        note: String? = nil,
        magicVariableTokens: [String]? = nil
    ) {
        self.id = id
        self.type = type
        self.target = target
        self.title = title
        self.menuPath = menuPath
        self.onlyWhenAppActive = onlyWhenAppActive
        self.outputVariables = outputVariables
        self.actionParameters = actionParameters
        self.ifBranch = ifBranch
        self.repeatLoop = repeatLoop
        self.chooseFromMenu = chooseFromMenu
        self.useModel = useModel
        self.writingTool = writingTool
        self.imagePlayground = imagePlayground
        self.isSkipped = isSkipped
        self.note = note
        self.magicVariableTokens = magicVariableTokens
    }

    /// 이 단계를 실행 가능한 임시 바인딩으로 변환
    func toBinding() -> HotKeyBinding {
        HotKeyBinding(
            combo: .empty,
            actionType: type,
            target: target,
            title: title,
            menuPath: menuPath,
            onlyWhenAppActive: onlyWhenAppActive
        )
    }

    /// 단계를 한 줄로 요약 (목록 표시용)
    var summary: String {
        if !title.isEmpty { return title }
        switch type {
        case .launchApp: return target
        case .menuCommand: return title
        case .file: return target
        case .url: return target
        case .script: return target
        case .system: return SystemActionType(rawValue: target)?.displayName ?? target
        case .paste: return target == "clipboard" ? "ui.editor.step_clipboard".localized : target
        case .wait: return "step.wait_fmt".localizedFormat(target)
        case .coordinateClick: return "\(target)"
        case .pauseUntilInput: return "ui.editor.step_pause".localized
        case .macro: return "step.keys_fmt".localizedFormat(target.components(separatedBy: ",").count)
        // 흐름 제어
        case .ifElse: return ifBranch.map { "flow.if_fmt".localizedFormat($0.condition.displayString) } ?? "flow.if_fmt".localizedFormat("")
        case .repeatLoop: return repeatLoop.map { $0.count.map { "step.repeat_count_fmt".localizedFormat($0) } ?? "ui.editor.step_repeat".localized } ?? "ui.editor.step_repeat".localized
        case .repeatEach: return repeatLoop.map { _ in "action.repeatEach".localized } ?? "action.repeatEach".localized
        case .chooseFromMenu: return chooseFromMenu.map { "step.menu_options_fmt".localizedFormat($0.options.count) } ?? "ui.editor.step_choose_menu".localized
        case .runShortcut: return target.isEmpty ? "action.runShortcut".localized : "step.run_shortcut_fmt".localizedFormat(target)
        case .stopShortcut: return "action.stopShortcut".localized
        case .endRepeat: return "action.endRepeat".localized
        case .comment: return note ?? "ui.editor.step_comment".localized
        // 변수
        case .setVariable: return "action.setVariable".localized
        case .variableDetail: return "action.variableDetail".localized
        case .number: return "step.number_fmt".localizedFormat(target)
        case .outputToVariable: return "action.outputToVariable".localized
        case .clipboardAction: return "action.clipboardAction".localized
        case .runScriptInShell: return "step.shell_fmt".localizedFormat(target)
        // AI
        case .useModel: return useModel?.displayName ?? "ui.editor.step_use_model".localized
        case .writingTool: return writingTool?.displayName ?? "ui.editor.step_writing_tool".localized
        case .imagePlayground: return imagePlayground?.displayName ?? "ui.editor.step_image".localized
        // 자동화
        case .automation: return "action.automation".localized
        case .findAutomation: return "action.findAutomation".localized
        case .automationRun: return "action.automationRun".localized
        case .trigger: return "action.trigger".localized
        // 앱
        case .appIntent: return "action.appIntent".localized
        case .appAction: return "action.appAction".localized
        case .findApp: return "action.findApp".localized
        default: return target
        }
    }
    
    /// 이 단계가 분기/반복/메뉴 같은 블록 구조를 가지는지
    var isBlockStructure: Bool {
        switch type {
        case .ifElse, .repeatLoop, .repeatEach, .chooseFromMenu:
            return true
        default:
            return false
        }
    }
    
    /// 중첩된 단계 목록 (블록 구조용)
    var nestedSteps: [ShortcutStep]? {
        switch type {
        case .ifElse:
            return ifBranch.map { $0.thenSteps + ($0.elseSteps ?? []) }
        case .repeatLoop, .repeatEach:
            return repeatLoop?.steps
        case .chooseFromMenu:
            return chooseFromMenu?.options.flatMap { _ in [] }  // MenuOption에는 steps가 없음
        default:
            return nil
        }
    }
}

// MARK: - ShortcutItem 확장

/// 하나의 동작(단축어) — 이름 + 순서 있는 단계들 + 글로벌 실행 단축키
struct ShortcutItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var steps: [ShortcutStep]
    var combo: HotKeyCombo
    
    // === iOS Shortcuts 확장 필드 ===
    
    /// 단축어 아이콘 (SF Symbol 또는 커스텀)
    var icon: ShortcutIcon
    /// 색상 (단축어 아이콘 배경색)
    var color: ShortcutColor
    /// Apple Intelligence 모델 타입 (전역 설정)
    var aiModel: AIModelType
    /// 단축어 설명
    var description: String
    /// macOS 시스템 단축어에 표시 여부
    var showInSystemShortcuts: Bool
    /// 개인 자동화 트리거 목록
    var automations: [AutomationTrigger]
    /// 사용자 정의 변수 목록
    var variables: [Variable]
    /// 생성일
    var createdAt: Date
    /// 수정일
    var modifiedAt: Date
    /// 마지막 실행일
    var lastRunAt: Date?
    /// 실행 횟수
    var runCount: Int
    /// 폴더 (그룹핑)
    var folder: String?
    /// 공유 가능 여부
    var isShareable: Bool
    /// 단축어 권한 (Apple Shortcuts에서 공유 시)
    var permissions: ShortcutPermissions

    init(
        id: UUID = UUID(),
        name: String,
        steps: [ShortcutStep] = [],
        combo: HotKeyCombo = .empty,
        icon: ShortcutIcon = .sfSymbol(name: "bolt.fill"),
        color: ShortcutColor = .blue,
        aiModel: AIModelType = .onDevice,
        description: String = "",
        showInSystemShortcuts: Bool = true,
        automations: [AutomationTrigger] = [],
        variables: [Variable] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        lastRunAt: Date? = nil,
        runCount: Int = 0,
        folder: String? = nil,
        isShareable: Bool = true,
        permissions: ShortcutPermissions = ShortcutPermissions()
    ) {
        self.id = id
        self.name = name
        self.steps = steps
        self.combo = combo
        self.icon = icon
        self.color = color
        self.aiModel = aiModel
        self.description = description
        self.showInSystemShortcuts = showInSystemShortcuts
        self.automations = automations
        self.variables = variables
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.lastRunAt = lastRunAt
        self.runCount = runCount
        self.folder = folder
        self.isShareable = isShareable
        self.permissions = permissions
    }
    
    /// 마지막 실행으로부터의 시간 포맷
    var lastRunFormatted: String {
        guard let lastRun = lastRunAt else { return "step.last_run_none".localized }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastRun, relativeTo: Date())
    }
    
    /// 실행 횟수 포맷
    var runCountFormatted: String {
        if runCount == 0 { return "step.executed_never".localized }
        if runCount == 1 { return "step.executed_once".localized }
        return "step.executed_fmt".localizedFormat(runCount)
    }
}

// MARK: - ShortcutIcon

/// 단축어 아이콘
enum ShortcutIcon: Codable, Hashable {
    case sfSymbol(name: String)
    case emoji(Character)
    
    enum CodingKeys: String, CodingKey { case sfSymbol, emoji }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let name = try c.decodeIfPresent(String.self, forKey: .sfSymbol) {
            self = .sfSymbol(name: name)
        } else if let chars = try c.decodeIfPresent(String.self, forKey: .emoji), let ch = chars.first {
            self = .emoji(ch)
        } else {
            self = .sfSymbol(name: "bolt.fill")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .sfSymbol(let name): try c.encode(name, forKey: .sfSymbol)
        case .emoji(let ch): try c.encode(String(ch), forKey: .emoji)
        }
    }
    
    var systemImage: String? {
        if case .sfSymbol(let name) = self { return name }
        return nil
    }
    
    var emojiCharacter: Character? {
        if case .emoji(let char) = self { return char }
        return nil
    }
    
    var displayName: String {
        switch self {
        case .sfSymbol(let name): return name
        case .emoji(let char): return String(char)
        }
    }
    
    /// iOS Shortcuts 아이콘 목록 (SF Symbol 기반)
    static let allSymbols: [ShortcutIcon] = [
        .sfSymbol(name: "bolt.fill"),
        .sfSymbol(name: "star.fill"),
        .sfSymbol(name: "heart.fill"),
        .sfSymbol(name: "music.note"),
        .sfSymbol(name: "camera.fill"),
        .sfSymbol(name: "envelope.fill"),
        .sfSymbol(name: "message.fill"),
        .sfSymbol(name: "calendar"),
        .sfSymbol(name: "map.fill"),
        .sfSymbol(name: "folder.fill"),
        .sfSymbol(name: "doc.text.fill"),
        .sfSymbol(name: "photo.fill"),
        .sfSymbol(name: "play.fill"),
        .sfSymbol(name: "gearshape.fill"),
        .sfSymbol(name: "bell.fill"),
        .sfSymbol(name: "hand.thumbsup.fill"),
        .sfSymbol(name: "globe"),
        .sfSymbol(name: "antenna.radiowaves.left.and.right"),
        .sfSymbol(name: "wifi"),
        .sfSymbol(name: "cloud.fill"),
        .sfSymbol(name: "lock.fill"),
        .sfSymbol(name: "key.fill"),
        .sfSymbol(name: "shield.fill"),
        .sfSymbol(name: "flame.fill"),
        .sfSymbol(name: "drop.fill"),
        .sfSymbol(name: "leaf.fill"),
        .sfSymbol(name: "sun.max.fill"),
        .sfSymbol(name: "moon.fill"),
        .sfSymbol(name: "snowflake"),
        .sfSymbol(name: "wind"),
        .sfSymbol(name: "cloud.rain.fill"),
        .sfSymbol(name: "cloud.bolt.fill"),
        .sfSymbol(name: "thermometer"),
        .sfSymbol(name: "barometer"),
        .sfSymbol(name: "airplane"),
        .sfSymbol(name: "car.fill"),
        .sfSymbol(name: "tram.fill"),
        .sfSymbol(name: "bicycle"),
        .sfSymbol(name: "figure.walk"),
        .sfSymbol(name: "bed.double.fill"),
        .sfSymbol(name: "sofa.fill"),
        .sfSymbol(name: "sink.fill"),
        .sfSymbol(name: "shower.fill"),
        .sfSymbol(name: "toilet.fill"),
        .sfSymbol(name: "bathtub.fill"),
        .sfSymbol(name: "mic.fill"),
        .sfSymbol(name: "speaker.wave.2.fill"),
        .sfSymbol(name: "headphones"),
        .sfSymbol(name: "pianokeys"),
        .sfSymbol(name: "guitars.fill"),
        .sfSymbol(name: "theatermasks.fill"),
        .sfSymbol(name: "paintpalette.fill"),
        .sfSymbol(name: "paintbrush.fill"),
        .sfSymbol(name: "pencil"),
        .sfSymbol(name: "pencil.and.outline"),
        .sfSymbol(name: "scissors"),
        .sfSymbol(name: "ruler"),
        .sfSymbol(name: "hammer.fill"),
        .sfSymbol(name: "wrench.fill"),
        .sfSymbol(name: "screwdriver.fill"),
        .sfSymbol(name: "bandage.fill"),
        .sfSymbol(name: "cross.fill"),
        .sfSymbol(name: "pill.fill"),
        .sfSymbol(name: "stethoscope"),
        .sfSymbol(name: "heart.text.clipboard"),
        .sfSymbol(name: "bandages.fill"),
        .sfSymbol(name: "person.fill"),
        .sfSymbol(name: "person.2.fill"),
        .sfSymbol(name: "person.3.fill"),
        .sfSymbol(name: "person.crop.circle.fill"),
        .sfSymbol(name: "person.crop.rectangle.stack.fill"),
        .sfSymbol(name: "cart.fill"),
        .sfSymbol(name: "creditcard.fill"),
        .sfSymbol(name: "banknote.fill"),
        .sfSymbol(name: "gift.fill"),
        .sfSymbol(name: "tag.fill"),
        .sfSymbol(name: "bag.fill"),
        .sfSymbol(name: "shippingbox.fill"),
        .sfSymbol(name: "archivebox.fill"),
        .sfSymbol(name: "checkmark.circle.fill"),
        .sfSymbol(name: "xmark.circle.fill"),
        .sfSymbol(name: "exclamationmark.circle.fill"),
        .sfSymbol(name: "questionmark.circle.fill"),
        .sfSymbol(name: "plus.circle.fill"),
        .sfSymbol(name: "minus.circle.fill"),
        .sfSymbol(name: "arrow.right.circle.fill"),
        .sfSymbol(name: "arrow.left.circle.fill"),
        .sfSymbol(name: "arrow.up.circle.fill"),
        .sfSymbol(name: "arrow.down.circle.fill"),
        .sfSymbol(name: "arrow.triangle.2.circlepath"),
        .sfSymbol(name: "repeat"),
        .sfSymbol(name: "shuffle"),
        .sfSymbol(name: "lock.rotation"),
        .sfSymbol(name: "keyid"),
        .sfSymbol(name: "digitalcrown.horizontal.lock.fill"),
        .sfSymbol(name: "faceid"),
        .sfSymbol(name: "touchid"),
        .sfSymbol(name: "fingerprint"),
        .sfSymbol(name: "qrcode"),
        .sfSymbol(name: "barcode"),
        .sfSymbol(name: "textformat.abc"),
        .sfSymbol(name: "textformat.123"),
        .sfSymbol(name: "function"),
        .sfSymbol(name: "number"),
        .sfSymbol(name: "text.cursor"),
        .sfSymbol(name: "textformat.size.larger"),
        .sfSymbol(name: "textformat.size.smaller"),
        .sfSymbol(name: "bold"),
        .sfSymbol(name: "italic"),
        .sfSymbol(name: "underline"),
        .sfSymbol(name: "strikethrough"),
        .sfSymbol(name: "text.justifyleft"),
        .sfSymbol(name: "text.justifycenter"),
        .sfSymbol(name: "text.justifyright"),
        .sfSymbol(name: "list.bullet"),
        .sfSymbol(name: "list.number"),
        .sfSymbol(name: "list.bullet.indent"),
        .sfSymbol(name: "list.dash"),
        .sfSymbol(name: "checklist"),
        .sfSymbol(name: "list.bullet.rectangle"),
        .sfSymbol(name: "tablecells"),
        .sfSymbol(name: "rectangle.grid.2x2"),
        .sfSymbol(name: "rectangle.grid.3x2"),
        .sfSymbol(name: "rectangle.grid.3x3"),
        .sfSymbol(name: "rectangle.split.3x1"),
        .sfSymbol(name: "rectangle.split.3x3"),
        .sfSymbol(name: "sidebar.left"),
        .sfSymbol(name: "sidebar.right"),
        .sfSymbol(name: "sidebar.leading"),
        .sfSymbol(name: "sidebar.trailing"),
        .sfSymbol(name: "rectangle.dashed"),
        .sfSymbol(name: "rectangle.on.rectangle"),
        .sfSymbol(name: "rectangle.stack"),
        .sfSymbol(name: "rectangle.3.group"),
        .sfSymbol(name: "cube"),
        .sfSymbol(name: "pyramid"),
        .sfSymbol(name: "diamond"),
        .sfSymbol(name: "hexagon"),
        .sfSymbol(name: "octagon"),
        .sfSymbol(name: "pentagon"),
        .sfSymbol(name: "triangle"),
        .sfSymbol(name: "circle"),
        .sfSymbol(name: "square"),
        .sfSymbol(name: "heart"),
        .sfSymbol(name: "star"),
        .sfSymbol(name: "sparkles"),
        .sfSymbol(name: "wand.and.stars"),
        .sfSymbol(name: "wand.and.raspberries"),
        .sfSymbol(name: "paintbrush"),
        .sfSymbol(name: "paintpalette"),
        .sfSymbol(name: "photo"),
        .sfSymbol(name: "camera"),
        .sfSymbol(name: "video"),
        .sfSymbol(name: "mic"),
        .sfSymbol(name: "music.note"),
        .sfSymbol(name: "film"),
        .sfSymbol(name: "theatermasks"),
        .sfSymbol(name: "book"),
        .sfSymbol(name: "book.closed"),
        .sfSymbol(name: "doc.plaintext"),
        .sfSymbol(name: "doc.richtext"),
        .sfSymbol(name: "doc.text"),
        .sfSymbol(name: "doc.image"),
        .sfSymbol(name: "doc.zipper"),
        .sfSymbol(name: "folder"),
        .sfSymbol(name: "archivebox"),
        .sfSymbol(name: "printer"),
        .sfSymbol(name: "scanner"),
        .sfSymbol(name: "envelope"),
        .sfSymbol(name: "envelope.open"),
        .sfSymbol(name: "mail.stack"),
        .sfSymbol(name: "mail.fill"),
        .sfSymbol(name: "message"),
        .sfSymbol(name: "message.fill"),
        .sfSymbol(name: "phone"),
        .sfSymbol(name: "phone.fill"),
        .sfSymbol(name: "video.fill"),
        .sfSymbol(name: "play.fill"),
        .sfSymbol(name: "pause.fill"),
        .sfSymbol(name: "stop.fill"),
        .sfSymbol(name: "forward.fill"),
        .sfSymbol(name: "backward.fill"),
        .sfSymbol(name: "goForward"),
        .sfSymbol(name: "goBackward"),
        .sfSymbol(name: "shuffle"),
        .sfSymbol(name: "repeat"),
        .sfSymbol(name: "repeat.1"),
        .sfSymbol(name: "repeat.2"),
        .sfSymbol(name: "speaker.wave.1"),
        .sfSymbol(name: "speaker.wave.2"),
        .sfSymbol(name: "speaker.wave.3"),
        .sfSymbol(name: "speaker.fill"),
        .sfSymbol(name: "volume.fill"),
        .sfSymbol(name: "volume.2.fill"),
        .sfSymbol(name: "volume.3.fill"),
        .sfSymbol(name: "mic.fill"),
        .sfSymbol(name: "mic.slash.fill"),
        .sfSymbol(name: "mic.badge.xmark"),
        .sfSymbol(name: "mic.circle"),
        .sfSymbol(name: "mic.circle.fill"),
        .sfSymbol(name: "headphones"),
        .sfSymbol(name: "headphones.circle"),
        .sfSymbol(name: "airpods"),
        .sfSymbol(name: "airpodspro"),
        .sfSymbol(name: "airpodmax"),
        .sfSymbol(name: "applepencil"),
        .sfSymbol(name: "magicmouse.fill"),
        .sfSymbol(name: "magickeyboard.fill"),
        .sfSymbol(name: "desktopcomputer"),
        .sfSymbol(name: "laptopcomputer"),
        .sfSymbol(name: "ipad"),
        .sfSymbol(name: "iphone"),
        .sfSymbol(name: "applewatch"),
        .sfSymbol(name: "appletv"),
        .sfSymbol(name: "homepod"),
        .sfSymbol(name: "homepodmini"),
        .sfSymbol(name: "airplayvideo"),
        .sfSymbol(name: "airplayaudio"),
        .sfSymbol(name: "airplaycast"),
        .sfSymbol(name: "antenna.radiowaves.left.and.right"),
        .sfSymbol(name: "wifi"),
        .sfSymbol(name: "wifi.slash"),
        .sfSymbol(name: "wifi.circle"),
        .sfSymbol(name: "wifi.circle.fill"),
        .sfSymbol(name: "bluetooth"),
        .sfSymbol(name: "bluetooth.circle"),
        .sfSymbol(name: "bluetooth.circle.fill"),
        .sfSymbol(name: "bluetooth.slash"),
        .sfSymbol(name: "bolt"),
        .sfSymbol(name: "bolt.fill"),
        .sfSymbol(name: "bolt.circle"),
        .sfSymbol(name: "bolt.circle.fill"),
        .sfSymbol(name: "bolt.slash"),
        .sfSymbol(name: "bolt.badge.a"),
        .sfSymbol(name: "bolt.badge.a.fill"),
        .sfSymbol(name: "bolt.badge.plus"),
        .sfSymbol(name: "bolt.badge.plus.fill"),
        .sfSymbol(name: "bolt.badge.minus"),
        .sfSymbol(name: "bolt.badge.minus.fill"),
        .sfSymbol(name: "bolt.badge.right"),
        .sfSymbol(name: "bolt.badge.right.fill"),
        .sfSymbol(name: "bolt.badge.left"),
        .sfSymbol(name: "bolt.badge.left.fill"),
        .sfSymbol(name: "bolt.trianglebadge.exclamationmark"),
        .sfSymbol(name: "bolt.trianglebadge.exclamationmark.fill"),
        .sfSymbol(name: "bolt.filled"),
        .sfSymbol(name: "bolt.filled.circle"),
        .sfSymbol(name: "bolt.filled.circle.fill"),
        .sfSymbol(name: "bolt.filled.slash"),
        .sfSymbol(name: "bolt.filled.badge.a"),
        .sfSymbol(name: "bolt.filled.badge.a.fill"),
        .sfSymbol(name: "bolt.filled.badge.plus"),
        .sfSymbol(name: "bolt.filled.badge.plus.fill"),
        .sfSymbol(name: "bolt.filled.badge.minus"),
        .sfSymbol(name: "bolt.filled.badge.minus.fill"),
        .sfSymbol(name: "bolt.filled.badge.right"),
        .sfSymbol(name: "bolt.filled.badge.right.fill"),
        .sfSymbol(name: "bolt.filled.badge.left"),
        .sfSymbol(name: "bolt.filled.badge.left.fill"),
        .sfSymbol(name: "bolt.filled.trianglebadge.exclamationmark"),
        .sfSymbol(name: "bolt.filled.trianglebadge.exclamationmark.fill"),
    ]
}

// MARK: - ShortcutColor

/// 단축어 색상
enum ShortcutColor: String, Codable, CaseIterable, Identifiable {
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case cyan
    case blue
    case indigo
    case purple
    case pink
    case brown
    case gray
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .red: return "color.name.red".localized
        case .orange: return "color.name.orange".localized
        case .yellow: return "color.name.yellow".localized
        case .green: return "color.name.green".localized
        case .mint: return "color.name.mint".localized
        case .teal: return "color.name.teal".localized
        case .cyan: return "color.name.cyan".localized
        case .blue: return "color.name.blue".localized
        case .indigo: return "color.name.indigo".localized
        case .purple: return "color.name.purple".localized
        case .pink: return "color.name.pink".localized
        case .brown: return "color.name.brown".localized
        case .gray: return "color.name.gray".localized
        }
    }
    
    var colorHex: String {
        switch self {
        case .red: return "#FF3B30"
        case .orange: return "#FF9500"
        case .yellow: return "#FFCC00"
        case .green: return "#34C759"
        case .mint: return "#00C7BE"
        case .teal: return "#30B0C7"
        case .cyan: return "#32ADE6"
        case .blue: return "#007AFF"
        case .indigo: return "#5856D6"
        case .purple: return "#AF52DE"
        case .pink: return "#FF2D55"
        case .brown: return "#A2845E"
        case .gray: return "#8E8E93"
        }
    }
}

// MARK: - ShortcutPermissions

/// 단축어 권한 (Apple Shortcuts에서 공유 시 사용)
struct ShortcutPermissions: Codable, Hashable {
    var allowExporting: Bool = true
    var allowRunningOnMac: Bool = true
    var allowRunningOnWatch: Bool = false
    var allowRunningFromLockScreen: Bool = false
    var showOnLockScreen: Bool = false
    var requiresConfirmation: Bool = false
    
    init(
        allowExporting: Bool = true,
        allowRunningOnMac: Bool = true,
        allowRunningOnWatch: Bool = false,
        allowRunningFromLockScreen: Bool = false,
        showOnLockScreen: Bool = false,
        requiresConfirmation: Bool = false
    ) {
        self.allowExporting = allowExporting
        self.allowRunningOnMac = allowRunningOnMac
        self.allowRunningOnWatch = allowRunningOnWatch
        self.allowRunningFromLockScreen = allowRunningFromLockScreen
        self.showOnLockScreen = showOnLockScreen
        self.requiresConfirmation = requiresConfirmation
    }
}