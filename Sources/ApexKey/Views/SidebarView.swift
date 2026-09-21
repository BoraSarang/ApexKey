import SwiftUI

/// 왼쪽 사이드바 — 기능 스테이션 + 카테고리(카운트 배지). Pearcleaner 스타일, 전체 행 클릭.
struct SidebarView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme
    @Binding var selection: MainWindowView.SidebarSelection?
    @Binding var searchText: String

    var body: some View {
        List(selection: $selection) {
            // 최상단 고정 스테이션
            Section("ui.sidebar.app_shortcuts".localized) {
                Label("ui.sidebar.all_apps".localized, systemImage: "square.grid.2x2")
                    .badge(store.visibleApps().count)
                    .tag(MainWindowView.SidebarSelection.all)
            }

            // 카테고리 — 섹션 헤더 + 카운트 배지. 비어 있는(앱이 없는) 카테고리는 숨김
            Section("ui.category".localized) {
                ForEach(store.categoryOrder()) { category in
                    if store.visibleApps().contains(where: { $0.category == category }) {
                        categoryRow(category)
                    }
                }
            }

            Section("ui.sidebar.tools".localized) {
                Label("ui.shortcut".localized, systemImage: "square.stack.3d.up.fill")
                    .badge(store.shortcuts.count)
                    .tag(MainWindowView.SidebarSelection.tool(.shortcut))
                Label("ui.automation.title".localized, systemImage: "bolt.badge.clock")
                    .badge(store.automationTriggerCount)
                    .tag(MainWindowView.SidebarSelection.tool(.automation))
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(theme.sidebarBackground)
        .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 320)
        .safeAreaInset(edge: .bottom) {
            permissionFooter
        }
    }

    private func categoryRow(_ category: AppCategory) -> some View {
        let count = store.visibleApps().filter { $0.category == category }.count
        return Label(category.displayName, systemImage: category.symbolName)
            .badge(count)
            .tag(MainWindowView.SidebarSelection.category(category))
    }

    private var permissionFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsDivider()
            if PermissionHelper.isAccessibilityTrusted {
                summaryRow
            } else {
                Button {
                    PermissionHelper.requestAccessibility()
                } label: {
                    summaryRow
                }
                .buttonStyle(.plain)
                .help("ui.sidebar.ax_required_help".localized)
            }
        }
        .background(
            LinearGradient(
                colors: [theme.tertiaryBackground.opacity(0.9), theme.sidebarBackground.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .top) { SettingsDivider() }
    }

    private var summaryRow: some View {
        let bindingCount = store.bindings.count
        return HStack(spacing: 6) {
            Circle()
                .fill(PermissionHelper.isAccessibilityTrusted ? theme.successColor.opacity(0.6) : theme.errorColor)
                .frame(width: 8, height: 8)
            if PermissionHelper.isAccessibilityTrusted {
                Text("ui.sidebar.binding_counts".localizedFormat(bindingCount, store.shortcuts.count))
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            } else {
                Text("ui.sidebar.ax_required".localized)
                    .font(.caption)
                    .foregroundColor(theme.errorColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
