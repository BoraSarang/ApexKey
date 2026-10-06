import SwiftUI

/// 메뉴바 아이콘 그리드 (M-03 UI) — 시스템 + 서드파티 상태 아이템을 모아 실제 아이콘을 클릭.
/// Space=좌클릭·Return=우클릭 (설정에서 뒤바꿈 가능). Esc/재토글로 닫힘.
/// 클릭된 아이콘의 메뉴는 원래 위치(메뉴바 아래)에 뜨고 포인터만 그리드에서 이동한다.
struct MenuBarIconsGridView: View {
    typealias IconItem = MenuBarIconEnumerator.IconItem

    let icons: [IconItem]
    /// 행당 아이콘 수 (1...16)
    var columns: Int = 8
    /// Space/Return 매핑 뒤바꿈
    var swapClicks: Bool = false
    let onClose: () -> Void
    /// 아이콘 활성화 — rightClick=true면 우클릭
    let onActivate: (IconItem, Bool) -> Void

    @Environment(\.theme) private var theme
    @State private var selectedIndex = 0

    /// 그리드 키보드 이동 (순수 함수 — 테스트 고정)
    static func moveSelection(from index: Int, by delta: (dx: Int, dy: Int), columns: Int, count: Int) -> Int {
        guard count > 0, columns > 0 else { return 0 }
        let cols = max(1, columns)
        let row = index / cols + delta.dy
        var col = index % cols + delta.dx
        // 좌우 이동은 행을 넘어가지 않음 (마지막 행 짧음 대응은 클램프)
        col = min(max(col, 0), cols - 1)
        let next = row * cols + col
        return min(max(next, 0), count - 1)
    }

    private var effectiveColumns: Int { min(max(columns, 1), 16) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if icons.isEmpty {
                emptyState
            } else {
                grid
            }
            Divider()
            footer
        }
        .frame(width: 560, height: 400)
        .background(theme.cardBackground.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.secondaryBorder.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: theme.shadowColor.opacity(0.35), radius: 24, x: 0, y: 10)
        .onKeyPress(.escape) { onClose(); return .handled }
        .onKeyPress(.space) { activateSelected(rightClick: swapClicks); return .handled }
        .onKeyPress(.return) { activateSelected(rightClick: !swapClicks); return .handled }
        .onKeyPress(.leftArrow) { selectedIndex = Self.moveSelection(from: selectedIndex, by: (-1, 0), columns: effectiveColumns, count: icons.count); return .handled }
        .onKeyPress(.rightArrow) { selectedIndex = Self.moveSelection(from: selectedIndex, by: (1, 0), columns: effectiveColumns, count: icons.count); return .handled }
        .onKeyPress(.upArrow) { selectedIndex = Self.moveSelection(from: selectedIndex, by: (0, -1), columns: effectiveColumns, count: icons.count); return .handled }
        .onKeyPress(.downArrow) { selectedIndex = Self.moveSelection(from: selectedIndex, by: (0, 1), columns: effectiveColumns, count: icons.count); return .handled }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.grid.2x2")
                .font(.system(size: 16))
                .foregroundColor(theme.secondaryText)
            VStack(alignment: .leading, spacing: 1) {
                Text("menubar.icons.title".localized)
                    .font(.headline)
                Text("menubar.icons.count".localizedFormat(icons.count))
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(96), spacing: 4), count: effectiveColumns), spacing: 8) {
                ForEach(Array(icons.enumerated()), id: \.offset) { index, item in
                    cell(item, isSelected: index == selectedIndex)
                        .onTapGesture {
                            selectedIndex = index
                            onActivate(item, swapClicks ? true : false)
                        }
                }
            }
            .padding(14)
        }
    }

    private func cell(_ item: IconItem, isSelected: Bool) -> some View {
        VStack(spacing: 4) {
            if let image = MenuBarIconEnumerator.shared.thumbnail(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "circle.grid.2x2")
                    .font(.system(size: 28))
                    .foregroundColor(theme.secondaryText)
                    .frame(width: 32, height: 32)
            }
            Text(item.title)
                .font(.system(size: 10))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(isSelected ? theme.accentColor : theme.primaryText)
                .frame(height: 26)
        }
        .frame(width: 96)
        .padding(.vertical, 6)
        .background(isSelected ? theme.accentColor.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "circle.grid.2x2")
                .font(.system(size: 28))
                .foregroundColor(theme.secondaryText)
            Text("menubar.icons.empty".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var footer: some View {
        Text(swapClicks ? "menubar.icons.footer_hint_swapped".localized : "menubar.icons.footer_hint".localized)
            .font(.caption)
            .foregroundColor(theme.secondaryText)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
    }

    private func activateSelected(rightClick: Bool) {
        guard icons.indices.contains(selectedIndex) else { return }
        onActivate(icons[selectedIndex], rightClick)
    }
}
