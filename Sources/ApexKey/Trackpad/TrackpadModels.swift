import Foundation

// MARK: - 좌표 공간

/// 트랙패드 가장자리. 정규화 좌표는 **좌하단(0,0) → 우상단(1,1)** — y는 위로 갈수록 커진다.
enum TrackpadEdge: String, Codable, CaseIterable, Identifiable, Hashable {
    case right, left, top, bottom

    var id: String { rawValue }

    var displayName: String { "trackpad.edge.\(rawValue)".localized }

    /// 가장자리가 세로 슬라이더인가 (좌/우 = 세로, 위/아래 = 가로)
    var isVertical: Bool { self == .right || self == .left }
}

/// 슬라이더가 바꾸는 값
enum SliderTarget: String, Codable, CaseIterable, Identifiable, Hashable {
    case volume
    case brightness
    case shortcut

    var id: String { rawValue }
    var displayName: String { "trackpad.target.\(rawValue)".localized }
}

/// 슬라이더 값 매핑 방식
enum SliderMapping: String, Codable, CaseIterable, Identifiable, Hashable {
    /// 이동량을 그대로 값에 반영 (v2 기본)
    case continuous
    /// 14% 이동마다 1/16 스텝 (v0.33 방식 — 고급)
    case stepped

    var id: String { rawValue }
    var displayName: String { "trackpad.mapping.\(rawValue)".localized }
}

/// 제스처 종류
enum GestureKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case tap
    case swipe

    var id: String { rawValue }
    var displayName: String { "trackpad.kind.\(rawValue)".localized }
}

/// 스와이프 방향
enum GestureDirection: String, Codable, CaseIterable, Identifiable, Hashable {
    case up, down, left, right

    var id: String { rawValue }
    var displayName: String { "trackpad.dir.\(rawValue)".localized }
    /// 요약 1줄용 짧은 표기
    var symbol: String {
        switch self {
        case .up: return "↑"
        case .down: return "↓"
        case .left: return "←"
        case .right: return "→"
        }
    }
    /// 규칙 목록용 낱말 표기
    var word: String {
        switch self {
        case .up: return "trackpad.dir.word.up".localized
        case .down: return "trackpad.dir.word.down".localized
        case .left: return "trackpad.dir.word.left".localized
        case .right: return "trackpad.dir.word.right".localized
        }
    }
}

/// 제스처가 실행할 대상 종류 — 전부 기존 ApexKey 자산을 재사용한다.
enum GestureActionKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case workflow
    case hotkey
    case menu
    case system

    var id: String { rawValue }
    var displayName: String { "trackpad.action.\(rawValue)".localized }
    /// 목록 요약에 붙는 접두사 ("워크플로우 · …")
    var summaryPrefix: String { "trackpad.action.\(rawValue)".localized }
}

/// 적용 범위
enum GestureScope: String, Codable, CaseIterable, Identifiable, Hashable {
    case global
    case apps

    var id: String { rawValue }
    var displayName: String { "trackpad.scope.\(rawValue)".localized }
}

// MARK: - 실행 대상

/// 제스처가 실행할 대상의 실제 파라미터. nil 필드는 해당 종류에서 쓰지 않는다.
struct GestureAction: Codable, Hashable {
    var kind: GestureActionKind
    /// `.workflow` — ShortcutItem.id
    var shortcutID: UUID?
    /// `.hotkey` — HotKeyBinding.id
    var bindingID: UUID?
    /// `.menu` — 대상 앱 번들ID + 메뉴 경로(최상위 메뉴부터)
    var menuBundleID: String?
    var menuTitle: String?
    var menuPath: [String]
    /// `.system`
    var systemAction: SystemActionType?
    /// `.system` 중 파라미터가 필요한 동작 — 배경화면 이미지 경로 또는 활성화할 앱 번들ID
    var systemText: String?

    init(
        kind: GestureActionKind = .workflow,
        shortcutID: UUID? = nil,
        bindingID: UUID? = nil,
        menuBundleID: String? = nil,
        menuTitle: String? = nil,
        menuPath: [String] = [],
        systemAction: SystemActionType? = nil,
        systemText: String? = nil
    ) {
        self.kind = kind
        self.shortcutID = shortcutID
        self.bindingID = bindingID
        self.menuBundleID = menuBundleID
        self.menuTitle = menuTitle
        self.menuPath = menuPath
        self.systemAction = systemAction
        self.systemText = systemText
    }

    enum CodingKeys: String, CodingKey {
        case kind, shortcutID, bindingID, menuBundleID, menuTitle, menuPath, systemAction, systemText
    }
}

// MARK: - 규칙

/// 에지 슬라이더 규칙
struct EdgeSliderRule: Identifiable, Codable, Hashable {
    var id: UUID
    var enabled: Bool
    var edge: TrackpadEdge
    var fingers: Int
    var target: SliderTarget
    /// 0.5 ... 3.0
    var sensitivity: Double
    var inverted: Bool
    /// 트랙패드 폭 대비 비율 0.04 ... 0.25
    var edgeWidth: Double
    /// 이만큼 움직여야 켜진다 0.005 ... 0.08
    var startThreshold: Double
    /// 스텝 모드에서 값이 다시 바뀌는 최소 간격(초)
    var cooldown: Double
    /// 하단 15%에서 시작한 터치 무시 (팜 리젝트)
    var ignoreThumb: Bool
    /// 슬라이더 동작 중에만 스크롤 억제
    var suppressScroll: Bool
    /// `.shortcut` 대상일 때 실행할 워크플로우
    var shortcutID: UUID?
    /// 이 조합이 **정확히** 눌렸을 때만 발동한다 (비어 있으면 무수정자)
    var modifiers: GestureModifiers
    /// 연속 / 스텝
    var mapping: SliderMapping

    init(
        id: UUID = UUID(),
        enabled: Bool = true,
        edge: TrackpadEdge = .right,
        fingers: Int = 1,
        target: SliderTarget = .volume,
        sensitivity: Double = 1.5,
        inverted: Bool = false,
        edgeWidth: Double = 0.07,
        startThreshold: Double = 0.015,
        cooldown: Double = 0.12,
        ignoreThumb: Bool = true,
        suppressScroll: Bool = true,
        shortcutID: UUID? = nil,
        modifiers: GestureModifiers = [],
        mapping: SliderMapping = .continuous
    ) {
        self.id = id
        self.enabled = enabled
        self.edge = edge
        self.fingers = fingers
        self.target = target
        self.sensitivity = sensitivity
        self.inverted = inverted
        self.edgeWidth = edgeWidth
        self.startThreshold = startThreshold
        self.cooldown = cooldown
        self.ignoreThumb = ignoreThumb
        self.suppressScroll = suppressScroll
        self.shortcutID = shortcutID
        self.modifiers = modifiers
        self.mapping = mapping
    }

    enum CodingKeys: String, CodingKey {
        case id, enabled, edge, fingers, target, sensitivity, inverted
        case edgeWidth, startThreshold, cooldown, ignoreThumb, suppressScroll, shortcutID
        case modifiers, mapping
    }

    /// 하위 호환 — v1.8.1까지 저장된 JSON에는 `modifiers`·`mapping` 키가 없다.
    /// 없는 키는 각각 "없음"·"스텝"으로 읽는다(당시 동작 유지). 롤백해도 깨지지 않는다.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        edge = try container.decodeIfPresent(TrackpadEdge.self, forKey: .edge) ?? .right
        fingers = try container.decodeIfPresent(Int.self, forKey: .fingers) ?? 2
        target = try container.decodeIfPresent(SliderTarget.self, forKey: .target) ?? .volume
        sensitivity = try container.decodeIfPresent(Double.self, forKey: .sensitivity) ?? 1.0
        inverted = try container.decodeIfPresent(Bool.self, forKey: .inverted) ?? false
        edgeWidth = try container.decodeIfPresent(Double.self, forKey: .edgeWidth) ?? 0.15
        startThreshold = try container.decodeIfPresent(Double.self, forKey: .startThreshold) ?? 0.07
        cooldown = try container.decodeIfPresent(Double.self, forKey: .cooldown) ?? 0.12
        ignoreThumb = try container.decodeIfPresent(Bool.self, forKey: .ignoreThumb) ?? true
        suppressScroll = try container.decodeIfPresent(Bool.self, forKey: .suppressScroll) ?? true
        shortcutID = try container.decodeIfPresent(UUID.self, forKey: .shortcutID)
        modifiers = try container.decodeIfPresent(GestureModifiers.self, forKey: .modifiers) ?? []
        mapping = try container.decodeIfPresent(SliderMapping.self, forKey: .mapping) ?? .stepped
    }
}

/// 제스처 규칙
struct GestureRule: Identifiable, Codable, Hashable {
    var id: UUID
    var enabled: Bool
    var kind: GestureKind
    var fingers: Int
    /// `kind == .swipe`일 때만 사용
    var direction: GestureDirection
    /// 스와이프를 이어서 하면 간격마다 계속 실행
    var repeats: Bool
    var action: GestureAction
    var scope: GestureScope
    /// `scope == .apps`일 때만 사용
    var appBundleIDs: [String]
    /// 이 조합이 **정확히** 눌렸을 때만 발동한다 (비어 있으면 무수정자)
    var modifiers: GestureModifiers

    init(
        id: UUID = UUID(),
        enabled: Bool = true,
        kind: GestureKind = .tap,
        fingers: Int = 4,
        direction: GestureDirection = .left,
        repeats: Bool = false,
        action: GestureAction = GestureAction(),
        scope: GestureScope = .global,
        appBundleIDs: [String] = [],
        modifiers: GestureModifiers = []
    ) {
        self.id = id
        self.enabled = enabled
        self.kind = kind
        self.fingers = fingers
        self.direction = direction
        self.repeats = repeats
        self.action = action
        self.scope = scope
        self.appBundleIDs = appBundleIDs
        self.modifiers = modifiers
    }

    enum CodingKeys: String, CodingKey {
        case id, enabled, kind, fingers, direction, repeats, action, scope, appBundleIDs
        case modifiers
    }

    /// 하위 호환 — `modifiers` 키가 없으면 "없음"으로 읽는다.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        kind = try container.decodeIfPresent(GestureKind.self, forKey: .kind) ?? .tap
        fingers = try container.decodeIfPresent(Int.self, forKey: .fingers) ?? 3
        direction = try container.decodeIfPresent(GestureDirection.self, forKey: .direction) ?? .left
        repeats = try container.decodeIfPresent(Bool.self, forKey: .repeats) ?? false
        action = try container.decodeIfPresent(GestureAction.self, forKey: .action) ?? GestureAction()
        scope = try container.decodeIfPresent(GestureScope.self, forKey: .scope) ?? .global
        appBundleIDs = try container.decodeIfPresent([String].self, forKey: .appBundleIDs) ?? []
        modifiers = try container.decodeIfPresent(GestureModifiers.self, forKey: .modifiers) ?? []
    }
}

// MARK: - 표시용 요약

extension EdgeSliderRule {
    /// v0.33.0 시드 기본값 그대로인가 — 사용자가 값을 만지지 않은 규칙만
    /// 기본값 보정(v0.33.1) 대상으로 삼기 위한 판별.
    var isLegacySeedDefault: Bool {
        edgeWidth == 0.12
            && startThreshold == 0.06
            && cooldown == 0.25
            && sensitivity == 1.0
            && !inverted
    }

    /// v0.33.1 시드 기본값 그대로인가 — v2 프로필로 올릴 대상.
    /// (오른쪽 에지 · 두 손가락 · 볼륨 · 폭 15% · 7% · 쿨다운 120ms · 감도 1.0)
    var isSeedV2Default: Bool {
        edge == .right
            && fingers == 2
            && target == .volume
            && sensitivity == 1.0
            && !inverted
            && edgeWidth == 0.15
            && startThreshold == 0.07
            && cooldown == 0.12
            && shortcutID == nil
            && modifiers.isEmpty
    }

    /// "⌥ 오른쪽 에지 · 한 손가락 · 세로"
    var gestureSummary: String {
        let axis = edge.isVertical ? "trackpad.axis.vertical".localized : "trackpad.axis.horizontal".localized
        return modifiers.summaryPrefix + "trackpad.summary.slider.fmt".localizedFormat(
            edge.displayName, TrackpadFormatting.fingerWord(fingers), axis
        )
    }

    /// "볼륨 · 감도 1.5x · 반전 · 1/16 스텝"
    var targetSummary: String {
        var text = target.displayName
        text += " · " + "trackpad.sensitivity.value".localizedFormat(sensitivity)
        if inverted { text += " · " + "trackpad.inverted".localized }
        if mapping == .stepped { text += " · " + SliderMapping.stepped.displayName }
        return text
    }

    /// 같은 에지·수정자 조합을 두 규칙이 쓰는지 비교하기 위한 키
    var gestureKey: String {
        "slider:\(edge.rawValue):\(modifiers.rawValue)"
    }
}

extension GestureRule {
    /// "⌥ 네 손가락 탭" / "네 손가락 스와이프 ↓"
    var gestureSummary: String {
        let fingers = TrackpadFormatting.fingerWord(self.fingers)
        let base: String
        switch kind {
        case .tap:
            base = "trackpad.summary.tap.fmt".localizedFormat(fingers)
        case .swipe:
            base = "trackpad.summary.swipe.fmt".localizedFormat(fingers, direction.word)
        }
        return modifiers.summaryPrefix + base
    }

    /// "워크플로우 · 터미널에서 열기" — 이름 해석은 저장소가 필요하므로 호출부가 넘긴다.
    func actionSummary(resolve: (GestureAction) -> String) -> String {
        action.kind.summaryPrefix + " · " + resolve(action)
    }

    var scopeSummary: String {
        switch scope {
        case .global: return GestureScope.global.displayName
        case .apps: return "trackpad.scope.apps_count".localizedFormat(appBundleIDs.count)
        }
    }

    /// 같은 제스처를 두 규칙이 쓰는지 비교하기 위한 키
    var gestureKey: String {
        let base: String
        switch kind {
        case .tap: base = "tap:\(fingers)"
        case .swipe: base = "swipe:\(fingers):\(direction.rawValue)"
        }
        return "\(base):m\(modifiers.rawValue)"
    }

    /// macOS 시스템 제스처와 겹칠 수 있는 조합인가.
    /// 3·4손가락 스와이프는 Mission Control·Exposé·스페이스 전환과 같은 입력이다.
    var hasSystemConflict: Bool {
        kind == .swipe && (fingers == 3 || fingers == 4)
    }
}

enum TrackpadFormatting {
    /// 1 → "한", 2 → "두", ...
    static func fingerWord(_ count: Int) -> String {
        switch count {
        case 1: return "trackpad.finger.one".localized
        case 2: return "trackpad.finger.two".localized
        case 3: return "trackpad.finger.three".localized
        case 4: return "trackpad.finger.four".localized
        case 5: return "trackpad.finger.five".localized
        default: return "\(count)"
        }
    }

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    /// 작은 값은 소수 첫째 자리까지 — 1.5%와 2%를 구분해야 한다.
    static func percentFine(_ value: Double) -> String {
        let percent = value * 100
        if percent < 10 {
            return String(format: "%.1f%%", percent)
        }
        return "\(Int(percent.rounded()))%"
    }

    static func milliseconds(_ seconds: Double) -> String {
        "\(Int((seconds * 1000).rounded()))ms"
    }
}
