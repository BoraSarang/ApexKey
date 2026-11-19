import AppKit

/// 제스처 발동에 필요한 수정자 키 조합.
///
/// 설계 규칙
/// - **정확 일치**: 규칙의 마스크와 현재 눌린 키가 같을 때만 발동한다.
///   (⌥ 규칙과 무수정자 규칙이 동시에 뜨는 것을 막는다)
/// - **슬라이더 채널은 ⇧를 쓰지 않는다**: ⇧는 "미세 조정" 전역 제스처로 예약한다.
/// - 저장은 `rawValue` 하나(Int)로 한다 — JSON에 객체를 중첩하지 않는다.
struct GestureModifiers: OptionSet, Hashable {
    let rawValue: Int

    static let control = GestureModifiers(rawValue: 1 << 0)
    static let option = GestureModifiers(rawValue: 1 << 1)
    static let shift = GestureModifiers(rawValue: 1 << 2)
    static let command = GestureModifiers(rawValue: 1 << 3)

    static let all: GestureModifiers = [.control, .option, .shift, .command]
    /// 에지 슬라이더가 쓸 수 있는 키 — ⇧는 미세 조정이라 제외한다.
    static let sliderMask: GestureModifiers = [.control, .option, .command]

    /// ⌃⌥⇧⌘ 표시 순서 (macOS 관례)
    static let displayOrder: [GestureModifiers] = [.control, .option, .shift, .command]

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    init() {
        self.rawValue = 0
    }

    // MARK: - 현재 상태

    /// 지금 눌린 수정자 키. 캡스락·Fn·숫자패드 등은 무시한다.
    static func current() -> GestureModifiers {
        from(NSEvent.modifierFlags)
    }

    static func from(_ flags: NSEvent.ModifierFlags) -> GestureModifiers {
        let device = flags.intersection(.deviceIndependentFlagsMask)
        var result: GestureModifiers = []
        if device.contains(.control) { result.insert(.control) }
        if device.contains(.option) { result.insert(.option) }
        if device.contains(.shift) { result.insert(.shift) }
        if device.contains(.command) { result.insert(.command) }
        return result
    }

    // MARK: - 표시

    /// "⌃⌥" — 없으면 빈 문자열
    var symbolString: String {
        Self.displayOrder
            .filter { contains($0) }
            .map(\.symbol)
            .joined()
    }

    /// 규칙 요약 앞에 붙는 접두사 — "⌥ " 또는 ""
    var summaryPrefix: String {
        let symbols = symbolString
        return symbols.isEmpty ? "" : symbols + " "
    }

    /// UI 칩 라벨 — "없음" / "⌃⌥"
    var displayName: String {
        let symbols = symbolString
        return symbols.isEmpty ? "trackpad.modifier.none".localized : symbols
    }

    /// 각 키의 접근성 이름 (버튼 툴팁)
    var accessibilityName: String {
        Self.displayOrder
            .filter { contains($0) }
            .map(\.keyName)
            .joined(separator: " + ")
    }

    var symbol: String {
        switch self {
        case .control: return "⌃"
        case .option: return "⌥"
        case .shift: return "⇧"
        case .command: return "⌘"
        default: return "?"
        }
    }

    var keyName: String {
        switch self {
        case .control: return "trackpad.modifier.control".localized
        case .option: return "trackpad.modifier.option".localized
        case .shift: return "trackpad.modifier.shift".localized
        case .command: return "trackpad.modifier.command".localized
        default: return symbol
        }
    }
}

// MARK: - Codable

extension GestureModifiers: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(Int.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
