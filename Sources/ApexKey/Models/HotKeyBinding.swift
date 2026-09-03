import Foundation

/// 등록된 글로벌 단축키 하나를 나타냄
struct HotKeyBinding: Identifiable, Codable, Hashable {
    var id: UUID
    var combo: HotKeyCombo
    var actionType: ActionType
    /// 대상 (번들ID / 파일 경로 / URL / 스크립트 명령)
    var target: String
    /// 메뉴 명령일 때의 메뉴 항목 제목 (표시용)
    var title: String
    /// 메뉴 명령 실행 경로 (최상위 메뉴 title부터 항목까지). 비어 있으면 title 기반 검색으로 fallback.
    var menuPath: [String]
    /// 앱이 활성화된 동안에만 실행 여부
    var onlyWhenAppActive: Bool

    init(
        id: UUID = UUID(),
        combo: HotKeyCombo,
        actionType: ActionType,
        target: String,
        title: String = "",
        menuPath: [String] = [],
        onlyWhenAppActive: Bool = false
    ) {
        self.id = id
        self.combo = combo
        self.actionType = actionType
        self.target = target
        self.title = title
        self.menuPath = menuPath
        self.onlyWhenAppActive = onlyWhenAppActive
    }
}
