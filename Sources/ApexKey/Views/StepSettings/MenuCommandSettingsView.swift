import SwiftUI

/// 메뉴 명령 단계 설정 (T-187, T-036 실구현).
///
/// `ShortcutEditorView.createDefaultStep`이 `.menuCommand`를 `target:""`로 만들어
/// 실행이 구조적으로 실패하던 문제를 닫는다. 앱 피커 → 메뉴 트리 선택으로
/// `target=번들ID`, `title=항목명`, `menuPath=경로`를 저장한다.
/// 실행은 기존 `ActionExecutor.menuCommand` 그대로 (값만 있으면 돈다).
struct MenuCommandSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep

    @State private var allApps: [AppItem] = []
    @State private var didLoad = false
    @State private var searchText = ""
    @State private var bundleID: String = ""
    @State private var menuItems: [MenuItem] = []
    @State private var menuLoaded = false

    private var filteredApps: [AppItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return Array(allApps.prefix(20)) }
        return allApps.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || $0.bundleID.lowercased().contains(q.lowercased())
        }.prefix(20).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(step.type.displayName)
                .font(.headline)

            Text("menucommand.app".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            if !didLoad {
                ProgressView().controlSize(.small)
            } else if bundleID.isEmpty {
                TextField("ui.app_detail.search_app".localized, text: $searchText)
                    .textFieldStyle(.roundedBorder)
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredApps) { app in
                            Button { selectApp(app.bundleID, name: app.name) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(app.name).font(.body)
                                        Text(app.bundleID)
                                            .font(.caption2)
                                            .foregroundColor(theme.secondaryText)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 140)
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(appName(for: bundleID)).font(.body)
                        Text(bundleID)
                            .font(.caption2)
                            .foregroundColor(theme.secondaryText)
                    }
                    Spacer()
                    Button("ui.app_detail.change_app".localized) {
                        bundleID = ""
                        step.target = ""
                        menuItems = []
                        menuLoaded = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Divider()

            Text("menucommand.menu".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            if bundleID.isEmpty {
                Text("menucommand.need_app".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            } else if !menuLoaded {
                ProgressView().controlSize(.small)
                    .onAppear(perform: loadMenu)
            } else if menuItems.isEmpty {
                Text("menucommand.not_running".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(menuItems) { item in
                            MenuCommandTreeNode(
                                item: item,
                                selectedPath: step.menuPath,
                                onSelect: { selectMenu($0) }
                            )
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .sectionCard()
        .onAppear(perform: initialLoad)
        .onChange(of: bundleID) { _, _ in loadMenu() }
    }

    private func initialLoad() {
        bundleID = step.target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !didLoad else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = AppFinder.installedApps().sorted { $0.name < $1.name }
            DispatchQueue.main.async {
                allApps = apps
                didLoad = true
                if !bundleID.isEmpty { loadMenu() }
            }
        }
    }

    private func appName(for id: String) -> String {
        allApps.first(where: { $0.bundleID == id })?.name ?? id
    }

    private func selectApp(_ id: String, name: String) {
        bundleID = id
        MenuCommandSelection.apply(bundleID: id, item: nil, to: &step)
        if step.title.isEmpty { step.title = name }
    }

    private func selectMenu(_ item: MenuItem) {
        MenuCommandSelection.apply(bundleID: bundleID, item: item, to: &step)
    }

    private func loadMenu() {
        guard !bundleID.isEmpty else { return }
        menuLoaded = false
        let id = bundleID
        DispatchQueue.global(qos: .userInitiated).async {
            let items = MenuEnumerator.shared.enumerateMenuItems(bundleID: id)
            DispatchQueue.main.async {
                // bundleID가 바뀌었으면 버린 결과 무시
                guard id == bundleID else { return }
                menuItems = items
                menuLoaded = true
            }
        }
    }
}

/// 단계 반영 순수 로직 — 단위테스트 대상 (AX 불필요).
enum MenuCommandSelection {
    static func apply(bundleID: String, item: MenuItem?, to step: inout ShortcutStep) {
        step.target = bundleID
        if let item {
            step.title = item.title
            step.menuPath = item.menuPath
        }
    }
}

private struct MenuCommandTreeNode: View {
    @Environment(\.theme) private var theme
    let item: MenuItem
    let selectedPath: [String]
    let onSelect: (MenuItem) -> Void
    @State private var isExpanded = true

    var body: some View {
        if item.isSeparator {
            Divider()
        } else if !item.children.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(spacing: 2) {
                    ForEach(item.children) { child in
                        MenuCommandTreeNode(item: child, selectedPath: selectedPath, onSelect: onSelect)
                    }
                }
                .padding(.leading, 8)
            } label: {
                HStack(spacing: 8) {
                    Text(item.title.isEmpty ? "ui.appdetail.submenu".localized : item.title)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(theme.secondaryText)
                }
                .padding(.vertical, 3)
                .contentShape(Rectangle())
            }
        } else {
            Button { onSelect(item) } label: {
                HStack(spacing: 8) {
                    Text(item.title.isEmpty ? "ui.station.separator".localized : item.title)
                        .lineLimit(1)
                    Spacer()
                    if item.hasKeyEquivalent {
                        KeycapView(menuItem: item)
                    }
                    if !selectedPath.isEmpty, selectedPath == item.menuPath {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(theme.successColor)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(item.title)
        }
    }
}
