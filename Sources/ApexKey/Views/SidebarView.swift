import SwiftUI

/// 왼쪽 사이드바 — 기능 스테이션 + 카테고리(카운트 배지). Pearcleaner 스타일, 전체 행 클릭.
struct SidebarView: View {
    @EnvironmentObject var store: ConfigStore
    @Binding var selection: MainWindowView.SidebarSelection?
    @Binding var searchText: String

    var body: some View {
        List(selection: $selection) {
            // 최상단 고정 스테이션
            Section("앱 단축키") {
                Label("전체 앱", systemImage: "square.grid.2x2")
                    .badge(store.visibleApps().count)
                    .tag(MainWindowView.SidebarSelection.all)
            }

            // 카테고리 — 섹션 헤더 + 카운트 배지 (Pearcleaner "사용자(18)/시스템(34)")
            Section("카테고리") {
                ForEach(store.categoryOrder()) { category in
                    categoryRow(category)
                }
            }

            Section("도구") {
                Label("스크립트", systemImage: "terminal")
                    .badge(store.scripts.count)
                    .tag(MainWindowView.SidebarSelection.script)
                Label("시스템", systemImage: "gearshape.2")
                    .tag(MainWindowView.SidebarSelection.system)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 320)
        .safeAreaInset(edge: .bottom) {
            permissionFooter
        }
    }

    private func categoryRow(_ category: AppCategory) -> some View {
        let count = store.visibleApps().filter { $0.category == category }.count
        let label: Label<Text, Image>
        switch category {
        case .browser:       label = Label("브라우저", systemImage: "globe")
        case .developer:     label = Label("개발", systemImage: "chevron.left.forwardslash.chevron.right")
        case .productivity:  label = Label("생산성", systemImage: "checklist")
        case .communication: label = Label("커뮤니케이션", systemImage: "bubble.left.and.bubble.right")
        case .media:         label = Label("미디어", systemImage: "play.rectangle")
        case .uncategorized: label = Label("기타", systemImage: "square.grid.3x3")
        }
        return label
            .badge(count)
            .tag(MainWindowView.SidebarSelection.category(category))
    }

    private var permissionFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack(spacing: 6) {
                Circle()
                    .fill(PermissionHelper.isAccessibilityTrusted ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(PermissionHelper.isAccessibilityTrusted ? "Accessibility 허용됨" : "Accessibility 필요")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.thinMaterial)
    }
}
