import Foundation
import SwiftData
import Combine

/// JSON blob 인코딩/디코딩 + 실패 로그 (R-05: 조용한 데이터 소실 방지)
enum StoreCoding {
    static func encode<T: Encodable>(_ value: T, label: String) -> Data {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            Logger.error("E-MAC-STORE-5002", "\(label) 인코딩 실패: \(error.localizedDescription)")
            return Data()
        }
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data, label: String, fallback: T) -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            Logger.error("E-MAC-STORE-5003", "\(label) 디코딩 실패: \(error.localizedDescription)")
            return fallback
        }
    }
}

/// SwiftData 영속 모델 — 등록된 앱
@Model
final class PersistedApp {
    var id: UUID
    var name: String
    var bundleID: String
    var path: String
    var categoryRaw: String
    var isHidden: Bool
    var categoryManuallySet: Bool?

    init(id: UUID = UUID(), name: String, bundleID: String, path: String,
         categoryRaw: String = "uncategorized", isHidden: Bool = false,
         categoryManuallySet: Bool = false) {
        self.id = id
        self.name = name
        self.bundleID = bundleID
        self.path = path
        self.categoryRaw = categoryRaw
        self.isHidden = isHidden
        self.categoryManuallySet = categoryManuallySet
    }

    func toAppItem() -> AppItem {
        let rawCategory: AppCategory =
            AppCategory(rawValue: categoryRaw) ?? AppCategory.migrate(categoryRaw)
        return AppItem(
            id: id,
            name: name,
            bundleID: bundleID,
            path: path,
            category: rawCategory,
            isHidden: isHidden,
            categoryManuallySet: categoryManuallySet ?? false
        )
    }

    static func from(_ app: AppItem) -> PersistedApp {
        PersistedApp(
            id: app.id,
            name: app.name,
            bundleID: app.bundleID,
            path: app.path,
            categoryRaw: app.category.rawValue,
            isHidden: app.isHidden,
            categoryManuallySet: app.categoryManuallySet
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
        self.menuPathRaw = menuPath.joined(separator: "\u{1F}")
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

/// SwiftData 영속 모델 — 동작(단축어)
@Model
final class PersistedShortcut {
    var id: UUID
    var name: String
    var comboKeyCode: UInt32
    var comboModifiers: UInt32
    var comboDisplayString: String
    /// 단계들을 JSON 직렬화해 저장 (Codable)
    var stepsData: Data
    
    // === iOS Shortcuts 확장 필드 ===
    var iconRaw: String        // SF Symbol 이름
    var colorRaw: String       // ShortcutColor rawValue
    var aiModelRaw: String     // AIModelType rawValue
    var descriptionText: String
    var showInSystemShortcuts: Bool
    var folderName: String?
    var isShareable: Bool
    var createdAt: Date
    var modifiedAt: Date
    var lastRunAt: Date?
    var runCount: Int
    
    /// 트리거를 JSON 직렬화해 저장
    var triggersData: Data
    /// 변수를 JSON 직렬화해 저장
    var variablesData: Data
    /// 권한을 JSON 직렬화해 저장
    var permissionsData: Data

    init(
        id: UUID = UUID(),
        name: String,
        steps: [ShortcutStep],
        combo: HotKeyCombo = .empty,
        icon: ShortcutIcon = .sfSymbol(name: "bolt.fill"),
        color: ShortcutColor = .blue,
        aiModel: AIModelType = .onDevice,
        description: String = "",
        showInSystemShortcuts: Bool = true,
        folder: String? = nil,
        isShareable: Bool = true,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        lastRunAt: Date? = nil,
        runCount: Int = 0,
        automations: [AutomationTrigger] = [],
        variables: [Variable] = [],
        permissions: ShortcutPermissions = ShortcutPermissions()
    ) {
        self.id = id
        self.name = name
        self.comboKeyCode = combo.keyCode
        self.comboModifiers = combo.modifiers
        self.comboDisplayString = combo.displayString
        self.stepsData = StoreCoding.encode(steps, label: "단축어 단계")
        self.iconRaw = icon.displayName
        self.colorRaw = color.rawValue
        self.aiModelRaw = aiModel.rawValue
        self.descriptionText = description
        self.showInSystemShortcuts = showInSystemShortcuts
        self.folderName = folder
        self.isShareable = isShareable
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.lastRunAt = lastRunAt
        self.runCount = runCount
        self.triggersData = StoreCoding.encode(automations, label: "자동화 트리거")
        self.variablesData = StoreCoding.encode(variables, label: "사용자 변수")
        self.permissionsData = StoreCoding.encode(permissions, label: "단축어 권한")
    }

    func toShortcut() -> ShortcutItem {
        let steps = StoreCoding.decode([ShortcutStep].self, from: stepsData, label: "단축어 단계", fallback: [])
        let triggers = StoreCoding.decode([AutomationTrigger].self, from: triggersData, label: "자동화 트리거", fallback: [])
        let variables = StoreCoding.decode([Variable].self, from: variablesData, label: "사용자 변수", fallback: [])
        let permissions = StoreCoding.decode(ShortcutPermissions.self, from: permissionsData, label: "단축어 권한", fallback: ShortcutPermissions())
        
        // 아이콘 디코딩 (기존 호환성 유지)
        let icon: ShortcutIcon
        if SF_SYMBOLS.contains(iconRaw) {
            icon = .sfSymbol(name: iconRaw)
        } else if let first = iconRaw.first {
            icon = .emoji(first)
        } else {
            icon = .sfSymbol(name: "bolt.fill")
        }
        
        return ShortcutItem(
            id: id,
            name: name,
            steps: steps,
            combo: HotKeyCombo(keyCode: comboKeyCode, modifiers: comboModifiers, displayString: comboDisplayString),
            icon: icon,
            color: ShortcutColor(rawValue: colorRaw) ?? .blue,
            aiModel: AIModelType(rawValue: aiModelRaw) ?? .onDevice,
            description: descriptionText,
            showInSystemShortcuts: showInSystemShortcuts,
            automations: triggers,
            variables: variables,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            lastRunAt: lastRunAt,
            runCount: runCount,
            folder: folderName,
            isShareable: isShareable,
            permissions: permissions
        )
    }

    static func from(_ s: ShortcutItem) -> PersistedShortcut {
        PersistedShortcut(
            id: s.id,
            name: s.name,
            steps: s.steps,
            combo: s.combo,
            icon: s.icon,
            color: s.color,
            aiModel: s.aiModel,
            description: s.description,
            showInSystemShortcuts: s.showInSystemShortcuts,
            folder: s.folder,
            isShareable: s.isShareable,
            createdAt: s.createdAt,
            modifiedAt: s.modifiedAt,
            lastRunAt: s.lastRunAt,
            runCount: s.runCount,
            automations: s.automations,
            variables: s.variables,
            permissions: s.permissions
        )
    }
}

// MARK: - SF Symbol 목록 (아이콘 디코딩용)

/// ShortcutIcon에서 사용하는 SF Symbol 이름 목록
private let SF_SYMBOLS: Set<String> = [
    "bolt.fill", "star.fill", "heart.fill", "music.note", "camera.fill",
    "envelope.fill", "message.fill", "calendar", "map.fill", "folder.fill",
    "doc.text.fill", "photo.fill", "play.fill", "gearshape.fill", "bell.fill",
    "hand.thumbsup.fill", "globe", "antenna.radiowaves.left.and.right", "wifi",
    "cloud.fill", "lock.fill", "key.fill", "shield.fill", "flame.fill",
    "drop.fill", "leaf.fill", "sun.max.fill", "moon.fill", "snowflake",
    "wind", "cloud.rain.fill", "cloud.bolt.fill", "thermometer", "barometer",
    "airplane", "car.fill", "tram.fill", "bicycle", "figure.walk",
    "bed.double.fill", "sofa.fill", "sink.fill", "shower.fill", "toilet.fill",
    "bathtub.fill", "mic.fill", "speaker.wave.2.fill", "headphones", "pianokeys",
    "guitars.fill", "theatermasks.fill", "paintpalette.fill", "paintbrush.fill",
    "pencil", "pencil.and.outline", "scissors", "ruler", "hammer.fill",
    "wrench.fill", "screwdriver.fill", "bandage.fill", "cross.fill", "pill.fill",
    "stethoscope", "heart.text.clipboard", "bandages.fill", "person.fill",
    "person.2.fill", "person.3.fill", "person.crop.circle.fill",
    "person.crop.rectangle.stack.fill", "cart.fill", "creditcard.fill",
    "banknote.fill", "gift.fill", "tag.fill", "bag.fill", "shippingbox.fill",
    "archivebox.fill", "checkmark.circle.fill", "xmark.circle.fill",
    "exclamationmark.circle.fill", "questionmark.circle.fill", "plus.circle.fill",
    "minus.circle.fill", "arrow.right.circle.fill", "arrow.left.circle.fill",
    "arrow.up.circle.fill", "arrow.down.circle.fill", "arrow.triangle.2.circlepath",
    "repeat", "shuffle", "lock.rotation", "keyid", "faceid", "touchid",
    "fingerprint", "qrcode", "barcode", "textformat.abc", "textformat.123",
    "function", "number", "text.cursor", "textformat.size.larger",
    "textformat.size.smaller", "bold", "italic", "underline", "strikethrough",
    "text.justifyleft", "text.justifycenter", "text.justifyright", "list.bullet",
    "list.number", "list.bullet.indent", "list.dash", "checklist",
    "list.bullet.rectangle", "tablecells", "rectangle.grid.2x2",
    "rectangle.grid.3x2", "rectangle.grid.3x3", "rectangle.split.3x1",
    "rectangle.split.3x3", "sidebar.left", "sidebar.right", "sidebar.leading",
    "sidebar.trailing", "rectangle.dashed", "rectangle.on.rectangle",
    "rectangle.stack", "rectangle.3.group", "cube", "pyramid", "diamond",
    "hexagon", "octagon", "pentagon", "triangle", "circle", "square", "heart",
    "star", "sparkles", "wand.and.stars", "wand.and.raspberries", "paintbrush",
    "paintpalette", "photo", "camera", "video", "mic", "music.note", "film",
    "theatermasks", "book", "book.closed", "doc.plaintext", "doc.richtext",
    "doc.text", "doc.image", "doc.zipper", "folder", "archivebox", "printer",
    "scanner", "envelope", "envelope.open", "mail.stack", "mail.fill",
    "message", "message.fill", "phone", "phone.fill", "video.fill", "play.fill",
    "pause.fill", "stop.fill", "forward.fill", "backward.fill", "goForward",
    "goBackward", "shuffle", "repeat", "repeat.1", "repeat.2", "speaker.wave.1",
    "speaker.wave.2", "speaker.wave.3", "speaker.fill", "volume.fill",
    "volume.2.fill", "volume.3.fill", "mic.fill", "mic.slash.fill",
    "mic.badge.xmark", "mic.circle", "mic.circle.fill", "headphones",
    "headphones.circle", "airpods", "airpodspro", "airpodmax", "applepencil",
    "magicmouse.fill", "magickeyboard.fill", "desktopcomputer", "laptopcomputer",
    "ipad", "iphone", "applewatch", "appletv", "homepod", "homepodmini",
    "airplayvideo", "airplayaudio", "airplaycast", "antenna.radiowaves.left.and.right",
    "wifi", "wifi.slash", "wifi.circle", "wifi.circle.fill", "bluetooth",
    "bluetooth.circle", "bluetooth.circle.fill", "bluetooth.slash", "bolt",
    "bolt.fill", "bolt.circle", "bolt.circle.fill", "bolt.slash", "bolt.badge.a",
    "bolt.badge.a.fill", "bolt.badge.plus", "bolt.badge.plus.fill",
    "bolt.badge.minus", "bolt.badge.minus.fill", "bolt.badge.right",
    "bolt.badge.right.fill", "bolt.badge.left", "bolt.badge.left.fill",
    "bolt.trianglebadge.exclamationmark", "bolt.trianglebadge.exclamationmark.fill",
    "bolt.filled", "bolt.filled.circle", "bolt.filled.circle.fill",
    "bolt.filled.slash", "bolt.filled.badge.a", "bolt.filled.badge.a.fill",
    "bolt.filled.badge.plus", "bolt.filled.badge.plus.fill", "bolt.filled.badge.minus",
    "bolt.filled.badge.minus.fill", "bolt.filled.badge.right",
    "bolt.filled.badge.right.fill", "bolt.filled.badge.left",
    "bolt.filled.badge.left.fill", "bolt.filled.trianglebadge.exclamationmark",
    "bolt.filled.trianglebadge.exclamationmark.fill",
]