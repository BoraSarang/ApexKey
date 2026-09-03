import SwiftUI

/// Menu HUD — 현재 전면 앱의 전체 메뉴 단축키를 메뉴별 그룹으로 표시 + 검색 + 실행
/// ⇧⌥S로 토글, ESC / 재토글 / 외부 클릭으로 닫힘.
struct MenuCheatSheetView: View {
    let appName: String
    let appIcon: NSImage?
    /// (메뉴 이름, 해당 메뉴의 단축키 항목들)
    let groups: [(menu: String, items: [MenuItem])]
    /// ESC 등으로 닫기 (AppDelegate가 패널 숨김 처리)
    let onClose: () -> Void
    /// 항목 실행 — 선택 시 AppDelegate가 performAction + 닫기 처리
    let onRun: (MenuItem) -> Void

    @EnvironmentObject var store: ConfigStore

    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    var totalCount: Int {
        visibleGroups.reduce(0) { $0 + $1.items.count }
    }

    /// 설정값에 따라 단축키 없는 항목을 필터링한 표시용 그룹.
    private var visibleGroups: [(menu: String, items: [MenuItem])] {
        guard !store.showNoShortcutItems else { return groups }
        return groups.map { (menu: $0.menu, items: $0.items.filter { $0.hasKeyEquivalent }) }
            .filter { !$0.items.isEmpty }
    }

    /// 검색 평면 결과 (검색어 있을 때만 사용)
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

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            Divider()
            if visibleGroups.isEmpty {
                emptyState
            } else if isSearching {
                resultList
            } else {
                groupList
            }
            Divider()
            footer
        }
        .frame(width: 460, height: 420)
        .background(Color(.windowBackgroundColor).opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 10)
        .onAppear {
            isSearchFocused = true
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
        .onKeyPress(.return) {
            if let item = currentItem {
                run(item)
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveSelection(-1)
            return .handled
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(appName)
                    .font(.headline)
                Text(isSearching ? "검색 결과 \(searchResults.count)개" : "메뉴 단축키 \(totalCount)개")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("단축키 / 명령 검색 (Enter 실행)", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var groupList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(visibleGroups, id: \.menu) { group in
                    if !group.items.isEmpty {
                        groupSection(group)
                    }
                }
            }
            .padding(14)
        }
    }

    private var resultList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if searchResults.isEmpty {
                    Text("일치하는 항목이 없습니다")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(24)
                } else {
                    ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, item in
                        selectableRow(item, isSelected: index == selectedIndex)
                    }
                }
            }
            .padding(8)
        }
    }

    private func groupSection(_ group: (menu: String, items: [MenuItem])) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group.menu)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            ForEach(group.items) { item in
                if item.isSeparator {
                    Divider()
                        .padding(.vertical, 2)
                } else {
                    row(item)
                }
            }
        }
    }

    private func row(_ item: MenuItem) -> some View {
        HStack(spacing: 12) {
            indentSpacer(item)
            Text(item.title)
                .font(.system(.body))
                .lineLimit(1)
            Spacer(minLength: 12)
            trailingSlot(item)
        }
        .contentShape(Rectangle())
        .onTapGesture { run(item) }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }

    private func selectableRow(_ item: MenuItem, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            indentSpacer(item)
            Text(item.title)
                .font(.system(.body))
                .lineLimit(1)
                .foregroundColor(isSelected ? Color.accentColor : .primary)
            Spacer(minLength: 12)
            trailingSlot(item)
        }
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture { run(item) }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    /// 서브메뉴 자식만 depth만큼 들여쓰기 (부모/최상위는 0이라 공간 없음)
    @ViewBuilder
    private func indentSpacer(_ item: MenuItem) -> some View {
        if item.depth > 0 {
            Text("")
                .frame(width: CGFloat(item.depth) * 14)
        }
    }

    /// macOS 표준대로 단축키를 오른쪽에 배치.
    /// 서브메뉴 부모는 '▸' 화살표, 단축키 있으면 keycap, 없으면 고정 빈칸.
    @ViewBuilder
    private func trailingSlot(_ item: MenuItem) -> some View {
        if item.isSubmenu {
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(minWidth: 24)
        } else if item.hasKeyEquivalent {
            Text(item.keyEquivalentDisplay)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        } else {
            Text("")
                .frame(width: 24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "command")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("단축키가 있는 메뉴 항목을 찾지 못했습니다")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var footer: some View {
        Text("ESC 또는 ⇧⌥S로 닫기 · Enter로 실행")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Selection / Run

    /// 현재 선택된 항목 (검색 결과가 우선, 그 외엔 첫 번째 그룹의 첫 항목)
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

    private func run(_ item: MenuItem) {
        guard !item.isSubmenu else { return }
        onRun(item)
    }
}