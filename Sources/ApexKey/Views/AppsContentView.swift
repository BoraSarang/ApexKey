import SwiftUI

/// 앱 목록 콘텐츠 (선택 카테고리 or 전체 + 검색 필터) — theamed Pearcleaner 스타일 밀도 높은 행
struct AppsContentView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme
    let category: AppCategory?
    var searchText: String = ""
    /// 단축키가 설정된 앱만 표시 (툴바 토글)
    var showOnlyWithShortcuts = false
    var onSelect: (AppItem) -> Void

    var body: some View {
        // filteredApps는 body당 1회만 평가 — header/count/List가 각자 호출하면
        // 3배 + 행마다 bindings(for:) N+1이 곱해진다.
        let apps = filteredApps
        let bindingCounts = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, store.bindings(for: $0.id).count) })
        return VStack(spacing: 0) {
            header(count: apps.count)
            SettingsDivider()
            if apps.isEmpty {
                emptyState
            } else {
                appList(apps: apps, bindingCounts: bindingCounts)
            }
        }
        .background(theme.primaryBackground)
    }

    private var title: String {
        category?.displayName ?? "ui.sidebar.all_apps".localized
    }

    private func header(count: Int) -> some View {
        HStack {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(theme.primaryText)
            Spacer()
            Text("ui.apps.count".localizedFormat(count))
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
        store.filteredVisibleApps(category: category, query: searchText, showOnlyWithShortcuts: showOnlyWithShortcuts)
    }

    private func appList(apps: [AppItem], bindingCounts: [UUID: Int]) -> some View {
        List(apps) { app in
            AppRowView(app: app, bindingCount: bindingCounts[app.id] ?? 0) {
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
/// bindingCount는 부모가 1회 계산해 주입 (행마다 bindings(for:) N+1 방지).
struct AppRowView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme
    let app: AppItem
    var bindingCount: Int? = nil
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
            let count = bindingCount ?? store.bindings(for: app.id).count
            if count > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "command")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.successColor)
                    Text("\(count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.successColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(theme.successColor.opacity(0.2))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(theme.successColor.opacity(0.4), lineWidth: 1)
                )
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
        if let img = AppIconCache.icon(for: app) {
            return Image(nsImage: img)
                .resizable()
                .frame(width: 28, height: 28)
        }
        return Image(systemName: "app.badge")
            .frame(width: 28, height: 28)
    }
}
