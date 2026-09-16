import SwiftUI

/// 선택된 앱의 상세 — 설정된 글로벌 단축키 + 앱의 메뉴 단축키 목록 (Pearcleaner 스타일 섹션)
struct AppDetailView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme
    let app: AppItem
    var onBack: () -> Void = {}
    @State private var menuItems: [MenuItem] = []
    @State private var isLoadingMenu = false
    @State private var recordingTarget: MenuItem?
    @State private var menuSearchText = ""
    @State private var recordingLaunch = false
    @State private var running = false
    @State private var urlSchemes: [String] = []
    @State private var urlSchemesExpanded = false
    @State private var recordingScheme: String?

    /// 저장소의 최신 앱 상태 (카테고리 변경 등 즉시 반영용)
    private var liveApp: AppItem {
        store.apps.first(where: { $0.id == app.id }) ?? app
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    launchSection
                    configuredSection
                    urlSchemeSection
                    menuSection
                }
                .padding(16)
            }
        }
        .background(theme.primaryBackground)
        .frame(minWidth: 440, minHeight: 480)
        .task {
            running = AppSwitcher.isRunning(bundleID: app.bundleID)
            urlSchemes = AppFinder.urlSchemes(for: app.path)
            reloadMenu()
        }
        .sheet(item: $recordingTarget) { target in
            HotKeyRecorderView(
                title: target.title.trimmingCharacters(in: .whitespacesAndNewlines),
                subtitle: "ui.appdetail.execute_then_menu".localizedFormat(app.name),
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
                title: "ui.appdetail.run_toggle".localizedFormat(app.name),
                subtitle: "ui.appdetail.run_globally".localized,
                excludedCombo: store.launchBindings(for: app.id).first?.combo,
                onTest: { _ in AppSwitcher.toggle(bundleID: app.bundleID) }
            ) { combo in
                store.setLaunchBinding(for: app.id, combo: combo)
            }
            .environmentObject(store)
        }
        .sheet(isPresented: Binding(
            get: { recordingScheme != nil },
            set: { if !$0 { recordingScheme = nil } }
        )) {
            HotKeyRecorderView(
                title: "\(app.name) (\(recordingScheme ?? "")://)",
                subtitle: "ui.appdetail.open_url".localized,
                onTest: { _ in if let s = recordingScheme { NSWorkspace.shared.open(URL(string: "\(s)://")!) }; return true }
            ) { combo in
                if let s = recordingScheme { onRecord(combo: combo, scheme: s) }
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
            .help("ui.appdetail.back_to_list".localized)

            icon
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(app.bundleID)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                AppSwitcher.activate(bundleID: app.bundleID, path: app.path)
            } label: {
                Image(systemName: running ? "arrow.up.left.and.arrow.down.right" : "play.fill")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.borderless)
            .help(running ? "ui.appdetail.front".localizedFormat(app.name) : "ui.appdetail.run_app".localizedFormat(app.name))
            Menu {
                ForEach(AppCategory.allCases) { category in
                    Button {
                        store.updateCategory(for: app.id, to: category)
                    } label: {
                        if category == liveApp.category {
                            Label(category.displayName, systemImage: "checkmark")
                        } else {
                            Text(category.displayName)
                        }
                    }
                }
            } label: {
                Text(liveApp.category.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(theme.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .menuStyle(.borderlessButton)
            .help("ui.appdetail.change_category".localized)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - 0) 앱 실행/토글 단축키

    private var launchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("ui.appdetail.run_toggle_label".localized, systemImage: "arrow.up.to.line")
            let list = store.launchBindings(for: app.id)
            HStack(spacing: 10) {
                Button {
                    recordingLaunch = true
                } label: {
                    Label(list.isEmpty ? "ui.appdetail.add_hotkey".localized : "ui.appdetail.change_hotkey".localized, systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
                Spacer()
                if let binding = list.first {
                    Text(binding.combo.displayString)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.tertiaryBackground.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Button {
                        store.removeBinding(binding)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(theme.secondaryText)
                    }
                    .buttonStyle(.borderless)
                    .help("ui.delete".localized)
                } else {
                    Text("ui.appdetail.no_hotkey".localized)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(12)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.cardBorder.opacity(0.3), lineWidth: 1))
    }

    // MARK: - 1) 설정된 글로벌 단축키

    private var configuredSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("ui.appdetail.configured_hotkeys".localized, systemImage: "pin")
            let list = store.bindings(for: app.id).filter { $0.actionType != .launchApp }
            if list.isEmpty {
                Text("ui.appdetail.no_hotkey_assigned".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                VStack(spacing: 4) {
                    ForEach(list) { binding in
                        configuredRow(binding)
                    }
                }
            }
        }
        .padding(12)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.cardBorder.opacity(0.3), lineWidth: 1))
    }

    private func configuredRow(_ binding: HotKeyBinding) -> some View {
        HStack(spacing: 10) {
            Text(binding.title.isEmpty ? "ui.command".localized : binding.title)
                .lineLimit(1)
            Spacer()
            Text(binding.combo.displayString)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(theme.tertiaryBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Button {
                store.removeBinding(binding)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(theme.secondaryText)
            }
            .buttonStyle(.borderless)
            .help("ui.delete".localized)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - 2) 앱 메뉴 단축키

    private var menuSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("ui.appdetail.menu_hotkeys".localizedFormat(app.name), systemImage: "command")
                Spacer()
                Button {
                    reloadMenu()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("ui.appdetail.refresh".localized)
            }
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.secondaryText)
                TextField("ui.appdetail.search_menu_commands".localized, text: $menuSearchText)
                    .textFieldStyle(.plain)
                if !menuSearchText.isEmpty {
                    Button {
                        menuSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(theme.inputBackground.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            menuList
        }
        .padding(12)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.cardBorder.opacity(0.3), lineWidth: 1))
    }

    private var menuList: some View {
        let query = menuSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return Group {
            if isLoadingMenu {
                HStack { Spacer(); ProgressView(); Spacer() }.padding()
            } else if menuItems.isEmpty {
                Text(isAccessibilityReady
                     ? "ui.appdetail.no_menu_items".localized
                     : "ui.appdetail.accessibility_required".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            } else if query.isEmpty {
                MenuTreeView(
                    items: menuItems,
                    alreadySet: { item in store.bindings(for: app.id).contains { $0.title == item.title } },
                    onRecord: { recordingTarget = $0 }
                )
            } else {
                let flat = MenuEnumerator.shared.allItems(in: menuItems)
                let items = flat.filter {
                    $0.title.lowercased().contains(query) || $0.keyEquivalentDisplay.lowercased().contains(query)
                }
                if items.isEmpty {
                    Text("ui.appdetail.no_search_results".localized)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
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
                    .foregroundColor(theme.secondaryText)
            }
            if alreadySet {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(theme.successColor)
            }
            Button {
                recordingTarget = item
            } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.borderless)
            .help("ui.appdetail.record_hotkey".localized)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(theme.secondaryText)
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

    // MARK: - 3) 앱 URL scheme (보기 + 테스트 + 단축키)

    private var urlSchemeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if urlSchemes.isEmpty {
                sectionHeader("URL Scheme", systemImage: "link")
                Text(app.path.isEmpty
                     ? "ui.appdetail.urlscheme_unavailable".localized
                     : "ui.appdetail.no_urlscheme".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                DisclosureGroup(isExpanded: $urlSchemesExpanded) {
                    VStack(spacing: 6) {
                        ForEach(urlSchemes, id: \.self) { scheme in
                            HStack(spacing: 8) {
                                Text("\(scheme)://")
                                    .font(.system(.body, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(theme.accentColor.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                Spacer()
                                Button {
                                    NSWorkspace.shared.open(URL(string: "\(scheme)://")!)
                                } label: {
                                    Label("ui.run".localized, systemImage: "play.fill")
                                }
                                .buttonStyle(.borderless)
                                .help("ui.appdetail.try_urlscheme".localizedFormat(scheme))
                                Button {
                                    recordingScheme = scheme
                                } label: {
                                    Label("ui.hotkey".localized, systemImage: "command")
                                }
                                .buttonStyle(.borderless)
                                .help("ui.appdetail.hotkey_for_scheme".localized)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(theme.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    HStack {
                        sectionHeader("URL Scheme", systemImage: "link")
                        Spacer()
                        Text("ui.appdetail.scheme_count".localizedFormat(urlSchemes.count))
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)
                    }
                }
            }
        }
        .padding(12)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.cardBorder.opacity(0.3), lineWidth: 1))
    }

    private func onRecord(combo: HotKeyCombo, scheme: String) {
        guard !combo.isEmpty else { return }
        store.addBinding(HotKeyBinding(
            combo: combo,
            actionType: .url,
            target: "\(scheme)://",
            title: "\(app.name) (\(scheme))",
            onlyWhenAppActive: false
        ))
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
    @Environment(\.theme) private var theme
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
                        Text(item.title.isEmpty ? "ui.appdetail.submenu".localized : item.title)
                            .lineLimit(1)
                            .fontWeight(!item.title.isEmpty ? .medium : .regular)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)
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
                    .foregroundColor(theme.secondaryText)
            }
            if alreadySet(item) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(theme.successColor)
            }
            Button {
                onRecord(item)
            } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.borderless)
            .help("ui.appdetail.record_hotkey".localized)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
