import Foundation

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

    init(
        id: UUID = UUID(),
        type: ActionType,
        target: String,
        title: String = "",
        menuPath: [String] = [],
        onlyWhenAppActive: Bool = false
    ) {
        self.id = id
        self.type = type
        self.target = target
        self.title = title
        self.menuPath = menuPath
        self.onlyWhenAppActive = onlyWhenAppActive
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
        case .paste: return target == "clipboard" ? "클립보드" : target
        case .wait: return "\(target)초"
        case .coordinateClick: return "\(target)"
        case .pauseUntilInput: return "입력 대기"
        case .macro: return "\(target.components(separatedBy: ",").count)키"
        }
    }
}

/// 하나의 동작(단축어) — 이름 + 순서 있는 단계들 + 글로벌 실행 단축키
struct ShortcutItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var steps: [ShortcutStep]
    var combo: HotKeyCombo

    init(id: UUID = UUID(), name: String, steps: [ShortcutStep] = [], combo: HotKeyCombo = .empty) {
        self.id = id
        self.name = name
        self.steps = steps
        self.combo = combo
    }
}
