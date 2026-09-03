import SwiftUI

/// Menu HUD — 전체 보기 (전체 화면)
/// 화면을 dim 처리하고 중앙에 어두운 반투명 패널로 모든 메뉴 단축키를 표시.
/// 각 메뉴를 하나의 컬럼으로 좌→우 배치(상단 정렬), 하단 검색창, 클릭/Enter 실행, ESC 닫힘.
struct MenuHUDOverlayView: View {
    let appName: String
    let appIcon: NSImage?
    /// (메뉴 이름, 해당 메뉴의 단축키 항목들)
    let groups: [(menu: String, items: [MenuItem])]
    let onClose: () -> Void
    let onRun: (MenuItem) -> Void

    @EnvironmentObject var store: ConfigStore

    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    var totalCount: Int {
        visibleGroups.reduce(0) { $0 + $1.items.count }
    }

    /// 설정값에 따라 단축키 없는 항목을 필터링한 표시용 그룹.
    /// (기본: 단축키 없는 메뉴도 포함 — 글로벌 단축키 할당 대상이므로)
    private var visibleGroups: [(menu: String, items: [MenuItem])] {
        guard !store.showNoShortcutItems else { return groups }
        return groups.map { (menu: $0.menu, items: $0.items.filter { $0.hasKeyEquivalent }) }
            .filter { !$0.items.isEmpty }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchResults: [MenuItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        var all: [MenuItem] = []
        for group in visibleGroups { all.append(contentsOf: group.items) }
        return all.filter {
            !$0.isSeparator
                && ($0.title.lowercased().contains(query)
                    || $0.keyEquivalentDisplay.lowercased().contains(query))
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            panel
        }
        .onAppear { isSearchFocused = true }
        .onChange(of: searchText) { _, _ in selectedIndex = 0 }
        .onKeyPress(.escape) { onClose(); return .handled }
        .onKeyPress(.return) {
            if let item = currentItem, !item.isSubmenu { onRun(item) }
            return .handled
        }
        .onKeyPress(.downArrow) { moveSelection(1); return .handled }
        .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.white.opacity(0.2))
            if visibleGroups.isEmpty {
                emptyState
            } else if isSearching {
                resultList
            } else {
                grid
            }
            Divider().overlay(Color.white.opacity(0.2))
            searchBar
        }
        .frame(maxWidth: 1120, maxHeight: 700)
        .background(Color.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 16)
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: "app")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(appName)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(isSearching ? "검색 결과 \(searchResults.count)개" : "메뉴 단축키 \(totalCount)개")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("⌘ CMD  ·  ⌃ Ctrl  ·  ⇧ Shift  ·  ⌥ Option  ·  🌐 지구본")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
                Toggle("단축키 없는 메뉴 표시", isOn: Binding(
                    get: { store.showNoShortcutItems },
                    set: { store.showNoShortcutItems = $0 }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var grid: some View {
        // 4개의 세로 열로 메뉴 분할 — 위→아래로 차곡차곡(상단 정렬), 열끼리 독립이라
        // "이동"이 "OpenCode" 바로 아래 세로로 이어지고 중간에 빈 공간이 생기지 않는다.
        // 4열 틀(빈 칸 포함)을 유지하되 첫 열이 화면 가장 왼쪽에 오도록 좌측 정렬한다.
        // ScrollView는 세로 전용으로 명시해, 가로로는 패널 폭에 고정되어 HStack의
        // maxWidth:.infinity(좌측 정렬용)가 안전하게 동작한다.
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: 30) {
                ForEach(menuColumns.indices, id: \.self) { index in
                    let column = menuColumns[index]
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(column, id: \.menu) { menu in
                            if !menu.items.isEmpty {
                                menuColumnView(menu)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// groups를 항상 4개의 세로 열로 분할 (메뉴를 4개 열에 위→아래로 순찰 배치)
    /// 어떤 메뉴 개수든 높이를 4열로 맞춰 각 열이 25% 폭을 차지한다.
    private var menuColumns: [[(menu: String, items: [MenuItem])]] {
        let n = visibleGroups.count
        guard n > 0 else { return [] }
        var columns = Array(repeating: [(menu: String, items: [MenuItem])](), count: 4)
        for (index, menu) in visibleGroups.enumerated() {
            columns[index % 4].append(menu)
        }
        return columns
    }

    private func menuColumnView(_ menu: (menu: String, items: [MenuItem])) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(menu.menu)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(height: 1.5)
            ForEach(menu.items) { item in
                if item.isSeparator {
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)
                        .padding(.vertical, 2)
                } else {
                    row(item)
                }
            }
        }
        .frame(width: 240, alignment: .leading)
    }

    private var resultList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if searchResults.isEmpty {
                    Text("일치하는 항목이 없습니다")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(28)
                } else {
                    ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, item in
                        selectableRow(item, isSelected: index == selectedIndex)
                    }
                }
            }
            .padding(14)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func row(_ item: MenuItem) -> some View {
        HStack(spacing: 10) {
            indentSpacer(item)
            Text(item.title)
                .font(.system(size: 13))
                .lineLimit(1)
                .foregroundColor(.white)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            trailingSlot(item)
        }
        .contentShape(Rectangle())
        .onTapGesture { if !item.isSubmenu { onRun(item) } }
        .padding(.vertical, 2)
    }

    private func selectableRow(_ item: MenuItem, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            indentSpacer(item)
            Text(item.title)
                .font(.system(size: 13))
                .lineLimit(1)
                .foregroundColor(isSelected ? Color.orange : .white)
            Spacer(minLength: 4)
            trailingSlot(item)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(isSelected ? Color.orange.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture { if !item.isSubmenu { onRun(item) } }
    }

    /// 서브메뉴 자식만 depth만큼 들여쓰기 (부모/최상위는 0이라 공간 없음)
    /// Text("") 고정 프레임 — Color.clear는 flex 팽창으로 행 레이아웃을 깨뜨림
    @ViewBuilder
    private func indentSpacer(_ item: MenuItem) -> some View {
        if item.depth > 0 {
            Text("")
                .frame(width: CGFloat(item.depth) * 16)
        }
    }

    /// 행 오른쪽(트레일링) 슬롯 — macOS 표준대로 단축키를 오른쪽에 배치.
    /// 서브메뉴 부모는 '▸' 화살표, 단축키 있으면 keycap, 없으면 같은 폭/높이의 고정 빈칸.
    @ViewBuilder
    private func trailingSlot(_ item: MenuItem) -> some View {
        if item.isSubmenu {
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 52, height: 22)
        } else {
            shortcutSlot(item)
        }
    }

    /// 단축키가 있는 항목은 keycap을, 없는 항목은 같은 폭/높이의 고정 빈칸을 둬서
    /// 메뉴 이름 시작 위치가 항목 간 세로 정렬을 유지하게 한다.
    /// (frame(width:) 고정 — Color.clear+minWidth는 flex로 팽창해 레이아웃을 깨뜨림)
    @ViewBuilder
    private func shortcutSlot(_ item: MenuItem) -> some View {
        if item.hasKeyEquivalent {
            keycap(item.keyEquivalentDisplay)
        } else {
            Text("")
                .frame(width: 52, height: 22)
        }
    }

    /// 단축키 키캡 — KeyCue 스타일 (회색 캡슐)
    private func keycap(_ display: String) -> some View {
        Text(display)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .frame(minWidth: 52, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "command")
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.4))
            Text("단축키가 있는 메뉴 항목을 찾지 못했습니다")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            TextField("단축키 / 명령 검색 (Enter 실행)", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .focused($isSearchFocused)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.borderless)
            }
            Text("ESC로 닫기")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
    }

    private var currentItem: MenuItem? {
        if isSearching {
            guard !searchResults.isEmpty else { return nil }
            return searchResults[min(selectedIndex, searchResults.count - 1)]
        }
        return visibleGroups.first?.items.first
    }

    private func moveSelection(_ delta: Int) {
        guard isSearching else { return }
        let count = searchResults.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
    }
}
