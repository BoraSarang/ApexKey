import SwiftUI

/// 단축키 키캡 공통 뷰 (E-MAC-UX keycap).
/// Mac-Keycap-Studio 6종을 코드 렌더로 이식 — PNG 없이 라이트/다크·fontScale·커스텀테마 대응.
/// 색은 고정값이 아니라 theme 토큰이라 양쪽 모드에서 대비가 유지된다.
struct KeycapView: View {
    /// HotKeyCombo 1건 (nil이면 빈칸)
    var combo: HotKeyCombo?
    /// 타앱 메뉴 1건 (combo와 둘 중 하나만)
    var menuItem: MenuItem?
    /// 명시 스타일 (nil이면 저장된 현재값 — store 없는 뷰용)
    var style: KeycapStyle?
    /// 지정됨 강조 — 본래 단일 캡슐 붙여쓰기 + 엑센트색 (내가 지정한 단축키 표시용).
    /// false면 스타일대로 중립 렌더 (타앱 메뉴 고유 단축키·미지정).
    var highlighted: Bool = false
    /// 큰 표시 (레코더·키누름 설정용)
    var large: Bool = false

    @Environment(\.theme) private var theme
    @AppStorage("pref.keycapStyle") private var storedRaw: String = KeycapStyle.symbolUpper.rawValue

    private var effectiveStyle: KeycapStyle {
        if let style { return style }
        return KeycapStyle(rawValue: storedRaw) ?? .symbolUpper
    }

    private var modifiers: [KeyboardUtil.ModifierToken] {
        if let combo { return KeyboardUtil.modifierTokens(combo.modifiers) }
        if let menuItem { return menuItem.keycapModifiers }
        return []
    }

    private var key: KeyboardUtil.KeyToken? {
        if let combo {
            guard !combo.isEmpty else { return nil }
            return KeyboardUtil.keyToken(combo.keyCode)
        }
        if let menuItem {
            guard menuItem.hasKeyEquivalent else { return nil }
            return menuItem.keycapKey
        }
        return nil
    }

    /// 본래 단일 캡슐용 붙여쓰기 문자열 (저장 displayString 우선, 없으면 재생성)
    private var joinedDisplay: String {
        if let combo {
            if !combo.displayString.isEmpty { return combo.displayString }
            return KeyboardUtil.displayString(keyCode: combo.keyCode, modifiers: combo.modifiers)
        }
        if let menuItem { return menuItem.keyEquivalentDisplay }
        return ""
    }

    var body: some View {
        if modifiers.isEmpty && key == nil {
            Text("")
                .frame(width: large ? 120 : 52, height: large ? 48 : 20)
        } else if highlighted {
            // 지정됨 — 본래 단일 캡슐 붙여쓰기 + 엑센트 (할당 상태 강조용)
            Text(joinedDisplay)
                .font(.system(size: large ? 26 : 13, weight: .semibold, design: .monospaced))
                .foregroundColor(theme.accentColor)
                .padding(.horizontal, large ? 10 : 8)
                .padding(.vertical, large ? 6 : 3)
                .background(theme.accentColor.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: large ? 8 : 6)
                        .stroke(theme.accentColor.opacity(0.35), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: large ? 8 : 6))
        } else {
            HStack(spacing: large ? 6 : 2) {
                ForEach(Array(modifiers.enumerated()), id: \.offset) { _, m in
                    singleCap(symbol: m.symbol, upper: m.upper, lower: m.lower)
                }
                if let key {
                    singleCap(symbol: key.symbol, upper: key.upper, lower: key.lower, isMainKey: true)
                }
            }
        }
    }

    @ViewBuilder
    private func singleCap(symbol: String, upper: String, lower: String, isMainKey: Bool = false) -> some View {
        switch effectiveStyle {
        case .symbol:
            capBox { Text(symbol).font(capFont(symbol: true)) }
        case .upper:
            // 본키는 기호 그대로 (N·⏎) — 수식키만 약어
            capBox(wide: !isMainKey && upper.count > 2) { Text(isMainKey ? symbol : upper).font(capFont(symbol: isMainKey)) }
        case .symbolUpper:
            capBox {
                VStack(spacing: 0) {
                    Text(symbol).font(capSymbolFont())
                    Text(isMainKey ? symbol : upper).font(capLabelFont())
                }
                .lineLimit(1)
            }
        case .lower:
            capBox(wide: !isMainKey) { Text(isMainKey ? symbol : lower).font(capFont(symbol: isMainKey)) }
        case .symbolLower:
            capBox {
                VStack(spacing: 0) {
                    Text(symbol).font(capSymbolFont())
                    Text(isMainKey ? symbol.lowercased() : lower).font(capLabelFont())
                }
                .lineLimit(1)
            }
        case .inline:
            if isMainKey {
                capBox { Text(symbol).font(capFont(symbol: true)) }
            } else {
                capBox(wide: true) { Text("\(lower) · \(symbol)").font(capInlineFont()) }
            }
        }
    }

    @ViewBuilder
    private func capBox<Content: View>(wide: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        content()
            .foregroundColor(theme.primaryText)
            .padding(.horizontal, large ? 8 : (wide ? 5 : 4))
            .padding(.vertical, large ? 6 : 2)
            .frame(minWidth: large ? 0 : 0, minHeight: large ? 48 : 20)
            .background(theme.primaryText.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: large ? 8 : 5)
                    .stroke(theme.primaryText.opacity(0.1), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: large ? 8 : 5))
    }

    private func capFont(symbol: Bool) -> Font {
        .system(size: large ? 30 : (symbol ? 16 : 13), weight: .semibold, design: .monospaced)
    }

    private func capSymbolFont() -> Font {
        .system(size: large ? 26 : 15, weight: .semibold, design: .monospaced)
    }

    private func capLabelFont() -> Font {
        .system(size: large ? 10 : 7, weight: .semibold, design: .monospaced)
    }

    private func capInlineFont() -> Font {
        .system(size: large ? 14 : 12, weight: .semibold, design: .monospaced)
    }
}

/// HotKeyCombo 편의 생성자
extension KeycapView {
    init(combo: HotKeyCombo, style: KeycapStyle? = nil, large: Bool = false, highlighted: Bool = false) {
        self.combo = combo
        self.menuItem = nil
        self.style = style
        self.large = large
        self.highlighted = highlighted
    }

    init(menuItem: MenuItem, style: KeycapStyle? = nil, highlighted: Bool = false) {
        self.combo = nil
        self.menuItem = menuItem
        self.style = style
        self.large = false
        self.highlighted = highlighted
    }
}
