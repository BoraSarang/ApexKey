import SwiftUI

/// 앱 목록 콘텐츠 (선택 카테고리 or 전체 + 검색 필터) — theamed Pearcleaner 스타일 밀도 높은 행
struct AppsContentView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme
    let category: AppCategory?
    var searchText: String = ""
    var onSelect: (AppItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            SettingsDivider()
            if filteredApps.isEmpty {
                emptyState
            } else {
                appList
            }
        }
        .background(theme.primaryBackground)
    }

    private var title: String {
        category?.displayName ?? "ui.sidebar.all_apps".localized
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(theme.primaryText)
            Spacer()
            Text("ui.apps.count".localizedFormat(filteredApps.count))
                .font(.caption)
                .foregroundColor(theme.tertiaryText)
            Button {
                addAppManually()
            } label: {
                Image(systemName: "plus")
            }
            .help("ui.apps.add_app".localized)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var filteredApps: [AppItem] {
        var apps = store.visibleApps()
        if let category {
            apps = apps.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            apps = apps.filter { store.appMatchesSearch($0, query: q) }
        }
        return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var appList: some View {
        List(filteredApps) { app in
            AppRowView(app: app) {
                onSelect(app)
            }
            .environmentObject(store)
            .listRowBackground(theme.cardBackground)
        }
        .listStyle(.plain)
        .background(theme.primaryBackground)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(theme.tertiaryText)
            Text("ui.apps.no_apps".localized)
                .font(.headline)
                .foregroundColor(theme.tertiaryText)
            Button("ui.apps.add_app".localized) {
                addAppManually()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addAppManually() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            if let item = AppFinder.appItem(fromPicked: url) {
                store.addApp(item)
            }
        }
    }
}

/// 앱 한 줄 — 아이콘 + 이름/번들ID + 단축키 배지. 전체 행 클릭.
struct AppRowView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme
    let app: AppItem
    let onSelect: () -> Void

    private var running: Bool {
        AppSwitcher.isRunning(bundleID: app.bundleID)
    }

    var body: some View {
        HStack(spacing: 10) {
            icon
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .lineLimit(1)
                    .foregroundColor(theme.primaryText)
                Text(app.bundleID)
                    .font(.caption)
                    .foregroundColor(theme.tertiaryText)
                    .lineLimit(1)
            }
            Spacer()
            let bindings = store.bindings(for: app.id)
            if !bindings.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "command")
                        .font(.caption)
                        .foregroundColor(theme.successColor)
                    Text("\(bindings.count)")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(theme.successColor.opacity(0.12))
                .clipShape(Capsule())
            }
            Button {
                AppSwitcher.activate(bundleID: app.bundleID, path: app.path)
            } label: {
                Image(systemName: running ? "arrow.up.left.and.arrow.down.right" : "play.fill")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
            .help(running ? "ui.appdetail.front".localizedFormat(app.name) : "ui.appdetail.run_app".localizedFormat(app.name))
            Image(systemName: app.isHidden ? "eye.slash" : "chevron.right")
                .font(.caption)
                .foregroundStyle(theme.tertiaryText)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .opacity(app.isHidden ? 0.55 : 1)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor.opacity(theme.shadowOpacity), radius: 4, x: 0, y: 1)
        )
        .contextMenu {
            if app.isHidden {
                Button("ui.apps.unhide".localized) { store.toggleHidden(app) }
            } else {
                Button("ui.apps.hide".localized) { store.toggleHidden(app) }
            }
        }
        .onTapGesture {
            onSelect()
        }
    }

    private var icon: some View {
        if let path = app.path.isEmpty ? nil : app.path,
           let img = NSWorkspace.shared.icon(forFile: path) as NSImage? {
            return Image(nsImage: img)
                .resizable()
                .frame(width: 28, height: 28)
        }
        return Image(systemName: "app.badge")
            .frame(width: 28, height: 28)
    }
}
