import SwiftUI

/// 메인 사이드바 창 (Pearcleaner 스타일 2열 + 통합 툴바)
struct MainWindowView: View {
    @EnvironmentObject var store: ConfigStore
    @State private var selectedCategory: AppCategory?      // nil = 전체
    @State private var isScriptStation = false
    @State private var isSystemStation = false
    @State private var selectedApp: AppItem?
    @State private var searchText = ""

    enum SidebarSelection: Hashable {
        case all
        case category(AppCategory)
        case script
        case system
    }

    private var sidebarSelection: Binding<SidebarSelection?> {
        Binding(
            get: {
                if isScriptStation { return .script }
                if isSystemStation { return .system }
                if let c = selectedCategory { return .category(c) }
                return .all
            },
            set: { newValue in
                guard let newValue else { return }
                switch newValue {
                case .all:
                    selectedCategory = nil
                    isScriptStation = false
                    isSystemStation = false
                case .category(let c):
                    selectedCategory = c
                    isScriptStation = false
                    isSystemStation = false
                case .script:
                    selectedCategory = nil
                    isScriptStation = true
                    isSystemStation = false
                case .system:
                    selectedCategory = nil
                    isScriptStation = false
                    isSystemStation = true
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
                    store.alwaysOnTop.toggle()
                } label: {
                    Label(store.alwaysOnTop ? "항상 위에 해제" : "항상 위에", systemImage: store.alwaysOnTop ? "pin.fill" : "pin")
                        .foregroundStyle(store.alwaysOnTop ? Color.accentColor : Color.secondary)
                }
                .help("항상 위에 유지")
                Button {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                } label: {
                    Label("설정…", systemImage: "gearshape")
                }
                .help("설정 (⌘,)")
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
            .filter {
                $0.name.lowercased().contains(query) ||
                $0.bundleID.lowercased().contains(query) ||
                store.bindings(for: $0.id).contains { $0.combo.displayString.lowercased().contains(query) }
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        // 여러 앱이 매칭되면 목록에서 검색 필터 유지 (상세 이동 없음)
        guard matches.count == 1, let only = matches.first else {
            isScriptStation = false
            isSystemStation = false
            selectedCategory = nil
            selectedApp = nil
            return
        }
        isScriptStation = false
        isSystemStation = false
        selectedCategory = nil
        selectedApp = only
    }

    @ViewBuilder
    private var detailContent: some View {        if isScriptStation {
            ScriptsStationView()
                .environmentObject(store)
        } else if isSystemStation {
            SystemActionsView()
                .environmentObject(store)
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
    @Binding var text: String
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("앱 검색", text: $text)
                .textFieldStyle(.plain)
                .onSubmit(onSubmit)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("ApexKey.openSettings")
    static let togglePanel = Notification.Name("ApexKey.togglePanel")
    static let toggleMenuHUD = Notification.Name("ApexKey.toggleMenuHUD")
}
