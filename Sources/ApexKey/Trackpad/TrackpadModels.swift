import Foundation

// MARK: - 좌표 공간

/// 트랙패드 가장자리. 정규화 좌표는 좌상단(0,0) → 우하단(1,1).
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

    /// v0.33에서 실제로 동작하는 대상인가 (밝기는 P1)
    var isAvailable: Bool { self != .brightness }
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
    /// 0.5 ... 2.0
    var sensitivity: Double
    var inverted: Bool
    /// 트랙패드 폭 대비 비율 0.06 ... 0.25
    var edgeWidth: Double
    /// 이만큼 움직여야 켜진다 0.02 ... 0.12
    var startThreshold: Double
    /// 값이 다시 바뀌는 최소 간격(초) 0.1 ... 0.6
    var cooldown: Double
    /// 하단 15%에서 시작한 터치 무시 (팜 리젝트)
    var ignoreThumb: Bool
    /// 슬라이더 동작 중에만 스크롤 억제
    var suppressScroll: Bool
    /// `.shortcut` 대상일 때 실행할 워크플로우
    var shortcutID: UUID?

    init(
        id: UUID = UUID(),
        enabled: Bool = true,
        edge: TrackpadEdge = .right,
        fingers: Int = 2,
        target: SliderTarget = .volume,
        sensitivity: Double = 1.0,
        inverted: Bool = false,
        edgeWidth: Double = 0.12,
        startThreshold: Double = 0.06,
        cooldown: Double = 0.25,
        ignoreThumb: Bool = true,
        suppressScroll: Bool = true,
        shortcutID: UUID? = nil
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

    init(
        id: UUID = UUID(),
        enabled: Bool = true,
        kind: GestureKind = .tap,
        fingers: Int = 3,
        direction: GestureDirection = .left,
        repeats: Bool = false,
        action: GestureAction = GestureAction(),
        scope: GestureScope = .global,
        appBundleIDs: [String] = []
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
    }
}

// MARK: - 표시용 요약

extension EdgeSliderRule {
    /// "오른쪽 에지 · 두 손가락 · 세로"
    var gestureSummary: String {
        let axis = edge.isVertical ? "trackpad.axis.vertical".localized : "trackpad.axis.horizontal".localized
        return "trackpad.summary.slider.fmt".localizedFormat(
            edge.displayName, TrackpadFormatting.fingerWord(fingers), axis
        )
    }

    /// "볼륨 · 감도 1.0x · 반전"
    var targetSummary: String {
        var text: String
        switch target {
        case .volume: text = SliderTarget.volume.displayName
        case .brightness: text = "trackpad.target.brightness_p1".localized
        case .shortcut: text = "trackpad.target.shortcut".localized
        }
        text += " · " + "trackpad.sensitivity.value".localizedFormat(sensitivity)
        if inverted { text += " · " + "trackpad.inverted".localized }
        return text
    }
}

extension GestureRule {
    /// "세 손가락 탭" / "네 손가락 스와이프 ↓"
    var gestureSummary: String {
        let fingers = TrackpadFormatting.fingerWord(self.fingers)
        switch kind {
        case .tap:
            return "trackpad.summary.tap.fmt".localizedFormat(fingers)
        case .swipe:
            return "trackpad.summary.swipe.fmt".localizedFormat(fingers, direction.word)
        }
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
        switch kind {
        case .tap: return "tap:\(fingers)"
        case .swipe: return "swipe:\(fingers):\(direction.rawValue)"
        }
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

    static func milliseconds(_ seconds: Double) -> String {
        "\(Int((seconds * 1000).rounded()))ms"
    }
}
