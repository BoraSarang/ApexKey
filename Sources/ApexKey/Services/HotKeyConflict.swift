import Foundation

/// 같은 단축키 공유 실행 (Conflict palette) — 순수 로직 + 고정(pin) 영속.
/// Carbon은 동일 조합을 1건만 등록하므로, 첫 소유자가 등록을 들고
/// 나머지는 그림자 항목으로 같은 조합을 공유한다.
enum HotKeyConflict {
    /// 충돌 선택지 1건 (값 타입 스냅샷 — 실행 중 배열 변경에 안전).
    struct Target: Identifiable, Hashable {
        enum Kind: String, Hashable {
            case shortcut
            case binding
        }

        var id: UUID
        var kind: Kind
        var title: String
        var subtitle: String
        var comboDisplay: String
        var shortcut: ShortcutItem?
        var binding: HotKeyBinding?

        static func shortcut(_ s: ShortcutItem) -> Target {
            Target(
                id: s.id,
                kind: .shortcut,
                title: s.name,
                subtitle: "palette.section.shortcuts".localized,
                comboDisplay: s.combo.displayString,
                shortcut: s,
                binding: nil
            )
        }

        static func binding(_ b: HotKeyBinding) -> Target {
            Target(
                id: b.id,
                kind: .binding,
                title: b.title.isEmpty ? b.actionType.displayName : b.title,
                subtitle: b.actionType.displayName,
                comboDisplay: b.combo.displayString,
                shortcut: nil,
                binding: b
            )
        }
    }

    private static let pinKey = "HotKeyConflictPreferred.v1"

    /// "keyCode:modifiers" — 공유 판정·고정 키의 단일 출처.
    static func comboKey(_ combo: HotKeyCombo) -> String {
        "\(combo.keyCode):\(combo.modifiers)"
    }

    /// 같은 조합의 실행 후보 수집 (단축어 + 바인딩).
    static func targets(
        matching combo: HotKeyCombo,
        shortcuts: [ShortcutItem],
        bindings: [HotKeyBinding]
    ) -> [Target] {
        let key = comboKey(combo)
        var out: [Target] = shortcuts
            .filter { !$0.combo.isEmpty && comboKey($0.combo) == key }
            .map(Target.shortcut)
        out += bindings
            .filter { !$0.combo.isEmpty && comboKey($0.combo) == key }
            .map(Target.binding)
        return out
    }

    /// 고정된 선택 (⌘↩) — 이후 발화는 목록 없이 바로 실행.
    static func preferredID(for combo: HotKeyCombo, defaults: UserDefaults = .standard) -> UUID? {
        guard let raw = (defaults.dictionary(forKey: pinKey) as? [String: String])?[comboKey(combo)] else {
            return nil
        }
        return UUID(uuidString: raw)
    }

    static func setPreferred(_ id: UUID, for combo: HotKeyCombo, defaults: UserDefaults = .standard) {
        var dict = (defaults.dictionary(forKey: pinKey) as? [String: String]) ?? [:]
        dict[comboKey(combo)] = id.uuidString
        defaults.set(dict, forKey: pinKey)
    }

    static func clearPreferred(for combo: HotKeyCombo, defaults: UserDefaults = .standard) {
        var dict = (defaults.dictionary(forKey: pinKey) as? [String: String]) ?? [:]
        dict.removeValue(forKey: comboKey(combo))
        defaults.set(dict, forKey: pinKey)
    }

    /// 발화 해결 — 고정 → 1건 → 목록 순. 목록 표시는 호출부가 담당한다.
    enum Resolution {
        case run(Target)
        case choose([Target])
        case none
    }

    static func resolve(targets: [Target], preferredID: UUID?) -> Resolution {
        guard !targets.isEmpty else { return .none }
        if let pid = preferredID, let pinned = targets.first(where: { $0.id == pid }) {
            return .run(pinned)
        }
        if targets.count == 1 { return .run(targets[0]) }
        return .choose(targets)
    }
}
