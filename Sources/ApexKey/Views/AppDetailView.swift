import SwiftUI

/// 선택된 앱의 상세 — 설정된 글로벌 단축키 + 앱의 메뉴 단축키 목록 (Pearcleaner 스타일 섹션)
struct AppDetailView: View {
    @EnvironmentObject var store: ConfigStore
    let app: AppItem
    var onBack: () -> Void = {}
    @State private var menuItems: [MenuItem] = []
    @State private var isLoadingMenu = false
    @State private var recordingTarget: MenuItem?
    @State private var menuSearchText = ""
    @State private var recordingLaunch = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    launchSection
                    configuredSection
                    menuSection
                }
                .padding(16)
            }
        }
        .frame(minWidth: 440, minHeight: 480)
        .task {
            reloadMenu()
        }
        .sheet(item: $recordingTarget) { target in
            HotKeyRecorderView(
                title: target.title.trimmingCharacters(in: .whitespacesAndNewlines),
                subtitle: "\(app.name) 실행 후 메뉴 명령 수행",
                onTest: { combo in
                    var t = target
                    if t.menuPath.isEmpty { t.menuPath = [t.title] }
                    let binding = HotKeyBinding(
                        combo: combo,
                        actionType: .menuCommand,
                        target: app.bundleID,
                        title: t.title,
                        menuPath: t.menuPath,
                        onlyWhenAppActive: false
                    )
                    let result = ActionExecutor.shared.execute(binding)
                    return result
                }
            ) { combo in
                onRecord(combo: combo, menuItem: target)
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $recordingLaunch) {
            HotKeyRecorderView(
                title: "\(app.name) 실행/토글",
                subtitle: "전역에서 실행",
                excludedCombo: store.launchBindings(for: app.id).first?.combo,
                onTest: { _ in AppSwitcher.toggle(bundleID: app.bundleID) }
            ) { combo in
                store.setLaunchBinding(for: app.id, combo: combo)
            }
            .environmentObject(store)
        }
    }

    // MARK: - 헤더 (앱 헤더 카드, back)

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .help("목록으로")

            icon
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(app.bundleID)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(app.category.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - 0) 앱 실행/토글 단축키

    private var launchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("앱 실행/토글", systemImage: "arrow.up.to.line")
            let list = store.launchBindings(for: app.id)
            HStack(spacing: 10) {
                Button {
                    recordingLaunch = true
                } label: {
                    Label(list.isEmpty ? "단축키 추가" : "단축키 변경", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
                Spacer()
                if let binding = list.first {
                    Text(binding.combo.displayString)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Button {
                        store.removeBinding(binding)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("삭제")
                } else {
                    Text("없음 — 실행/포커스/토글 단축키를 설정하세요.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - 1) 설정된 글로벌 단축키

    private var configuredSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("설정된 글로벌 단축키", systemImage: "pin")
            // 앱 실행/토글 단축키는 위 launchSection에서 다루므로 제외
            let list = store.bindings(for: app.id).filter { $0.actionType != .launchApp }
            if list.isEmpty {
                Text("설정된 단축키가 없습니다. 아래 메뉴 단축키에서 선택해 추가하세요.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 4) {
                    ForEach(list) { binding in
                        configuredRow(binding)
                    }
                }
            }
        }
    }

    private func configuredRow(_ binding: HotKeyBinding) -> some View {
        HStack(spacing: 10) {
            Text(binding.title.isEmpty ? "명령" : binding.title)
                .lineLimit(1)
            Spacer()
            Text(binding.combo.displayString)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Button {
                store.removeBinding(binding)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("삭제")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - 2) 앱 메뉴 단축키

    private var menuSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("\(app.name)의 메뉴 단축키", systemImage: "command")
                Spacer()
                Button {
                    reloadMenu()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("새로고침")
            }
            // 메뉴 명령 검색
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("메뉴 명령 검색", text: $menuSearchText)
                    .textFieldStyle(.plain)
                if !menuSearchText.isEmpty {
                    Button {
                        menuSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            menuList
        }
    }

    private var menuList: some View {
        let query = menuSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return Group {
            if isLoadingMenu {
                HStack { Spacer(); ProgressView(); Spacer() }.padding()
            } else if menuItems.isEmpty {
                Text(isAccessibilityReady
                     ? "메뉴 단축키를 찾을 수 없습니다. 앱을 실행해두세요."
                     : "Accessibility 권한이 필요합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if query.isEmpty {
                // 검색어 없음 → 전체 메뉴를 펼침/접기 트리로 표시
                MenuTreeView(
                    items: menuItems,
                    alreadySet: { item in store.bindings(for: app.id).contains { $0.title == item.title } },
                    onRecord: { recordingTarget = $0 }
                )
            } else {
                // 검색어 있음 → 단축키 항목만 평면 검색 결과로 표시
                let flat = MenuEnumerator.shared.allItems(in: menuItems)
                let items = flat.filter {
                    $0.title.lowercased().contains(query) || $0.keyEquivalentDisplay.lowercased().contains(query)
                }
                if items.isEmpty {
                    Text("검색 결과가 없습니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 4) {
                        ForEach(items) { item in
                            menuRow(item)
                        }
                    }
                }
            }
        }
    }

    private func menuRow(_ item: MenuItem) -> some View {
        let alreadySet = store.bindings(for: app.id).contains { $0.title == item.title }
        return HStack(spacing: 10) {
            Text(item.title)
                .lineLimit(1)
            Spacer()
            if !item.keyEquivalentDisplay.isEmpty {
                Text(item.keyEquivalentDisplay)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            if alreadySet {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            Button {
                recordingTarget = item
            } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.borderless)
            .help("단축키 녹음")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.bottom, 2)
    }

    private var icon: some View {
        if let path = app.path.isEmpty ? nil : app.path,
           let img = NSWorkspace.shared.icon(forFile: path) as NSImage? {
            return Image(nsImage: img).resizable()
        }
        return Image(systemName: "app.badge")
    }

    private var isAccessibilityReady: Bool {
        PermissionHelper.isAccessibilityTrusted
    }

    private func reloadMenu() {
        guard PermissionHelper.isAccessibilityTrusted else { return }
        isLoadingMenu = true
        DispatchQueue.global(qos: .userInitiated).async {
            let items = MenuEnumerator.shared.enumerateMenuItems(bundleID: app.bundleID)
            DispatchQueue.main.async {
                menuItems = items
                isLoadingMenu = false
            }
        }
    }

    private func onRecord(combo: HotKeyCombo, menuItem: MenuItem) {
        guard !combo.isEmpty else { return }
        var menuItem = menuItem
        if menuItem.menuPath.isEmpty { menuItem.menuPath = [menuItem.title] }
        let binding = HotKeyBinding(
            combo: combo,
            actionType: .menuCommand,
            target: app.bundleID,
            title: menuItem.title,
            menuPath: menuItem.menuPath,
            onlyWhenAppActive: false
        )
        store.addBinding(binding)
    }
}

/// 메뉴 전체를 계층(트리)으로 렌더링 — 최상위 메뉴바 그룹은 기본 펼침, 하위 서브메뉴는 개별 펼침/접기
private struct MenuTreeView: View {
    let items: [MenuItem]
    let alreadySet: (MenuItem) -> Bool
    let onRecord: (MenuItem) -> Void

    var body: some View {
        VStack(spacing: 2) {
            ForEach(items) { item in
                MenuTreeNode(item: item, alreadySet: alreadySet, onRecord: onRecord, initiallyExpanded: true)
            }
        }
    }
}

/// 재귀 트리 노드 — 각 노드가 고유한 펼침 상태를 가짐
private struct MenuTreeNode: View {
    let item: MenuItem
    let alreadySet: (MenuItem) -> Bool
    let onRecord: (MenuItem) -> Void
    var initiallyExpanded: Bool

    @State private var isExpanded: Bool

    init(item: MenuItem, alreadySet: @escaping (MenuItem) -> Bool,
         onRecord: @escaping (MenuItem) -> Void, initiallyExpanded: Bool = false) {
        self.item = item
        self.alreadySet = alreadySet
        self.onRecord = onRecord
        self.initiallyExpanded = initiallyExpanded
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        if item.isSeparator {
            Divider().padding(.vertical, 2)
        } else if !item.children.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(spacing: 2) {
                    ForEach(item.children) { child in
                        MenuTreeNode(
                            item: child,
                            alreadySet: alreadySet,
                            onRecord: onRecord,
                            initiallyExpanded: false
                        )
                    }
                }
                .padding(.leading, 8)
            } label: {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack(spacing: 10) {
                        Text(item.title.isEmpty ? "(하위 메뉴)" : item.title)
                            .lineLimit(1)
                            .fontWeight(!item.title.isEmpty ? .medium : .regular)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } else {
            menuRow
        }
    }

    private var menuRow: some View {
        HStack(spacing: 10) {
            Text(item.title)
                .lineLimit(1)
            Spacer()
            if !item.keyEquivalentDisplay.isEmpty {
                Text(item.keyEquivalentDisplay)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            if alreadySet(item) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            Button {
                onRecord(item)
            } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.borderless)
            .help("단축키 녹음")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
