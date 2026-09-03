import SwiftUI

/// 앱 목록 콘텐츠 (선택 카테고리 or 전체 + 검색 필터) — Pearcleaner 스타일 밀도 높은 행
struct AppsContentView: View {
    @EnvironmentObject var store: ConfigStore
    let category: AppCategory?
    var searchText: String = ""
    var onSelect: (AppItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if filteredApps.isEmpty {
                emptyState
            } else {
                appList
            }
        }
    }

    private var title: String {
        category?.displayName ?? "전체 앱"
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            Spacer()
            Text("\(filteredApps.count)개")
                .font(.caption)
                .foregroundColor(.secondary)
            Button {
                addAppManually()
            } label: {
                Image(systemName: "plus")
            }
            .help("앱 추가")
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
            apps = apps.filter {
                $0.name.lowercased().contains(q) || $0.bundleID.lowercased().contains(q) ||
                store.bindings(for: $0.id).contains { $0.combo.displayString.lowercased().contains(q) }
            }
        }
        return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var appList: some View {
        List(filteredApps) { app in
            AppRowView(app: app) {
                onSelect(app)
            }
            .environmentObject(store)
        }
        .listStyle(.inset)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("앱이 없습니다")
                .font(.headline)
                .foregroundColor(.secondary)
            Button("앱 추가") {
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
    let app: AppItem
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            icon
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .lineLimit(1)
                Text(app.bundleID)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            let bindings = store.bindings(for: app.id)
            if !bindings.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "command")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("\(bindings.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.12))
                .clipShape(Capsule())
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
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
