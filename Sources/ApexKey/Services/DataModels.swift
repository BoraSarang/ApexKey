import Foundation
import SwiftData
import Combine

/// SwiftData 영속 모델 — 등록된 앱
@Model
final class PersistedApp {
    var id: UUID
    var name: String
    var bundleID: String
    var path: String
    var categoryRaw: String
    var isHidden: Bool

    init(id: UUID = UUID(), name: String, bundleID: String, path: String,
         categoryRaw: String = "uncategorized", isHidden: Bool = false) {
        self.id = id
        self.name = name
        self.bundleID = bundleID
        self.path = path
        self.categoryRaw = categoryRaw
        self.isHidden = isHidden
    }

    func toAppItem() -> AppItem {
        AppItem(
            id: id,
            name: name,
            bundleID: bundleID,
            path: path,
            category: AppCategory(rawValue: categoryRaw) ?? .uncategorized,
            isHidden: isHidden
        )
    }

    static func from(_ app: AppItem) -> PersistedApp {
        PersistedApp(
            id: app.id,
            name: app.name,
            bundleID: app.bundleID,
            path: app.path,
            categoryRaw: app.category.rawValue,
            isHidden: app.isHidden
        )
    }
}

/// SwiftData 영속 모델 — 글로벌 단축키 바인딩
@Model
final class PersistedBinding {
    var id: UUID
    var keyCode: UInt32
    var modifiers: UInt32
    var displayString: String
    var actionTypeRaw: String
    var target: String
    var title: String
    var menuPathRaw: String
    var onlyWhenAppActive: Bool

    init(id: UUID = UUID(), combo: HotKeyCombo, actionType: ActionType,
         target: String, title: String = "", menuPath: [String] = [], onlyWhenAppActive: Bool = false) {
        self.id = id
        self.keyCode = combo.keyCode
        self.modifiers = combo.modifiers
        self.displayString = combo.displayString
        self.actionTypeRaw = actionType.rawValue
        self.target = target
        self.title = title
        self.menuPathRaw = menuPath.joined(separator: "\u{1F}") // 구분자로 직렬화
        self.onlyWhenAppActive = onlyWhenAppActive
    }

    func toBinding() -> HotKeyBinding {
        HotKeyBinding(
            id: id,
            combo: HotKeyCombo(keyCode: keyCode, modifiers: modifiers, displayString: displayString),
            actionType: ActionType(rawValue: actionTypeRaw) ?? .launchApp,
            target: target,
            title: title,
            menuPath: menuPathRaw.isEmpty ? [] : menuPathRaw.components(separatedBy: "\u{1F}"),
            onlyWhenAppActive: onlyWhenAppActive
        )
    }

    static func from(_ b: HotKeyBinding) -> PersistedBinding {
        PersistedBinding(
            id: b.id,
            combo: b.combo,
            actionType: b.actionType,
            target: b.target,
            title: b.title,
            menuPath: b.menuPath,
            onlyWhenAppActive: b.onlyWhenAppActive
        )
    }
}
