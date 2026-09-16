import SwiftUI

/// 메인 사이드바 창 (Pearcleaner 스타일 2열 + 통합 툴바)
struct MainWindowView: View {
    @EnvironmentObject var store: ConfigStore
    @State private var selectedCategory: AppCategory?      // nil = 전체
    @State private var selectedTool: ToolSelection?
    @State private var selectedApp: AppItem?
    @State private var searchText = ""

    enum ToolSelection: Hashable {
        case shortcut
        case system
    }

    enum SidebarSelection: Hashable {
        case all
        case category(AppCategory)
        case tool(ToolSelection)
    }

    private var sidebarSelection: Binding<SidebarSelection?> {
        Binding(
            get: {
                if let t = selectedTool { return .tool(t) }
                if let c = selectedCategory { return .category(c) }
                return .all
            },
            set: { newValue in
                guard let newValue else { return }
                switch newValue {
                case .all:
                    selectedCategory = nil
                    selectedTool = nil
                case .category(let c):
                    selectedCategory = c
                    selectedTool = nil
                case .tool(let t):
                    selectedCategory = nil
                    selectedTool = t
                }
                selectedApp = nil
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: sidebarSelection, searchText: $searchText)
                .environmentObject(store)
        } detail: {
            detailContent
                .environmentObject(store)
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 320)
        .toolbar {
            // 검색 (왼쪽/principal)
            ToolbarItem(placement: .principal) {
                SearchField(text: $searchText, onSubmit: { submitSearch() })
                    .frame(width: 240)
            }
            // 항상 위에 토글 (활성/비활성 아이콘) + 설정 (우측 끝)
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.reclassifyCategories()
                } label: {
                    Label("ui.main.reclassify".localized, systemImage: "arrow.triangle.2.circlepath")
                }
                .help("ui.main.reclassify_help".localized)
                Button {
                    store.alwaysOnTop.toggle()
                } label: {
                    Label(store.alwaysOnTop ? "ui.main.always_on_top_off".localized : "ui.main.always_on_top".localized, systemImage: store.alwaysOnTop ? "pin.fill" : "pin")
                        .foregroundStyle(store.alwaysOnTop ? Color.accentColor : Color.secondary)
                }
                .help("ui.main.always_on_top_help".localized)
                Button {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                } label: {
                    Label("ui.main.settings".localized, systemImage: "gearshape")
                }
                .help("ui.main.settings_help".localized)
            }
        }
    }

    /// 메인 툴바 검색에서 엔터 시 — 매칭 앱이 1개면 상세로, 여러 개면 전체 앱 검색 목록 유지
    private func submitSearch() {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        let query = q.lowercased()
        // AppsContentView.filteredApps와 동일한 매칭 로직
        let matches = store.visibleApps()
            .filter { store.appMatchesSearch($0, query: query) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        // 여러 앱이 매칭되면 목록에서 검색 필터 유지 (상세 이동 없음)
        guard matches.count == 1, let only = matches.first else {
            selectedTool = nil
            selectedCategory = nil
            selectedApp = nil
            return
        }
        selectedTool = nil
        selectedCategory = nil
        selectedApp = only
    }

    @ViewBuilder
    private var detailContent: some View {
        if let tool = selectedTool {
            switch tool {
            case .shortcut:
                ShortcutStationView()
                    .environmentObject(store)
            case .system:
                SystemActionsView()
                    .environmentObject(store)
            }
        } else if let app = selectedApp {
            AppDetailView(app: app) {
                selectedApp = nil
            }
            .environmentObject(store)
        } else {
            AppsContentView(category: selectedCategory, searchText: searchText) { app in
                selectedApp = app
            }
            .environmentObject(store)
        }
    }
}

/// 툴바 검색 필드
struct SearchField: View {
    @Environment(\.theme) private var theme
    @Binding var text: String
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.tertiaryText)
            TextField("ui.main.search_apps".localized, text: $text)
                .textFieldStyle(.plain)
                .foregroundColor(theme.primaryText)
                .onSubmit(onSubmit)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.tertiaryBackground.opacity(0.7))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.primaryBorder.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("ApexKey.openSettings")
    static let togglePanel = Notification.Name("ApexKey.togglePanel")
    static let toggleMenuHUD = Notification.Name("ApexKey.toggleMenuHUD")
}
