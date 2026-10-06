import SwiftUI

/// 설정 탭 (기능별) — 안 쓰는 기능은 쳐다보지 않아도 되게 탭으로 분리.
/// 각 탭 상단에는 FeatureHelpCard(뭐고·언제·이렇게)가 붙는다.
enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case panel
    case palette
    case clipboard
    case send
    case hud
    case icons
    case theme

    var id: String { rawValue }

    var titleKey: String { "settings.tab.\(rawValue)" }

    var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .panel: return "macwindow"
        case .palette: return "command"
        case .clipboard: return "doc.on.clipboard"
        case .send: return "paperplane"
        case .hud: return "square.grid.3x3"
        case .icons: return "circle.grid.2x2"
        case .theme: return "paintpalette"
        }
    }

    /// 도움말 키 묶음 (what/when/how) — settings.help.<tab>.*
    var helpPrefix: String { "settings.help.\(rawValue)" }
}

/// 기능 탭 상단 도움말 카드 — "이 탭(기능)은 뭐고, 언제 쓰고, 이렇게 쓴다".
/// 정적 텍스트 3줄이라 가볍고, 행별 설명(삭제됨)을 대체한다.
struct FeatureHelpCard: View {
    /// settings.help.<tab> 접두사
    var prefix: String

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            helpRow(icon: "questionmark.circle", text: "\(prefix).what".localized, accent: false)
            helpRow(icon: "clock", text: "\(prefix).when".localized, accent: false)
            helpRow(icon: "hand.point.up", text: "\(prefix).how".localized, accent: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.accentColor.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.bottom, 4)
    }

    private func helpRow(icon: String, text: String, accent: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(accent ? theme.accentColor : theme.secondaryText)
                .frame(width: 16)
                .padding(.top, 1)
            Text(text)
                .font(.callout)
                .foregroundColor(accent ? theme.primaryText : theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
