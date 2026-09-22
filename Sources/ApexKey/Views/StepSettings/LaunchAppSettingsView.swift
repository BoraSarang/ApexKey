import AppKit
import SwiftUI

// MARK: - 앱 실행/토글 설정 (P0)

struct LaunchAppSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep
    @FocusState private var isSearchFocused: Bool
    @State private var searchText = ""
    @State private var allApps: [AppItem] = []
    @State private var didLoad = false
    /// 선택 후 목록 접힘 상태. 검색 필드 포커스 시 다시 펼침.
    @State private var listCollapsed = false
    /// 폼의 단일 진실 공급원. onAppear에서 step으로부터 초기화, 변경 시 step에 즉시 동기화.
    @State private var config = LaunchConfig()

    private var filteredApps: [AppItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = q.isEmpty ? Array(allApps.prefix(30)) : allApps.filter {
            PaletteMatch.matchesRanges(text: $0.name, query: q)
                || $0.bundleID.lowercased().contains(q.lowercased())
        }
        return base.prefix(30).map { $0 }
    }

    /// 선택된 앱 요약 (접힘 상태 표시용).
    private var selectedAppName: String? {
        guard !config.bundleID.isEmpty else { return nil }
        return allApps.first(where: { $0.bundleID == config.bundleID })?.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(step.type.displayName)
                .font(.headline)

            // 앱 검색
            TextField("ui.app_detail.search_app".localized, text: $searchText)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .onAppear(perform: loadApps)
                .onChange(of: isSearchFocused) { _, focused in
                    if focused { listCollapsed = false }
                }

            if !didLoad {
                ProgressView()
                    .controlSize(.small)
            } else if listCollapsed, !config.bundleID.isEmpty {
                // 선택됨 요약 행 (목록 접힘 상태)
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(selectedAppName ?? config.bundleID)
                            .font(.body)
                        Text(config.bundleID)
                            .font(.caption2)
                            .foregroundColor(theme.secondaryText)
                    }
                    Spacer()
                    Button("ui.app_detail.change_app".localized) {
                        listCollapsed = false
                        isSearchFocused = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            } else if filteredApps.isEmpty {
                Text("ui.catalog.no_results".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            } else {
                Text("ui.app_detail.app_count_fmt".localizedFormat(filteredApps.count))
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredApps) { app in
                            Button { selectApp(app) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(app.name).font(.body)
                                        Text(app.bundleID)
                                            .font(.caption2)
                                            .foregroundColor(theme.secondaryText)
                                    }
                                    Spacer()
                                    if config.bundleID == app.bundleID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }

            Divider()

            // 선택된 앱 수동 입력 (번들ID/경로)
            Text("ui.app_detail.bundle_id".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("com.apple.Safari", text: $config.bundleID)
                .textFieldStyle(.roundedBorder)
                .onChange(of: config.bundleID) { _, _ in syncToStep() }

            HStack {
                TextField("ui.path".localized, text: $config.path)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: config.path) { _, _ in syncToStep() }
                Button("ui.browse".localized) {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    panel.allowedContentTypes = [.applicationBundle]
                    if panel.runModal() == .OK, let url = panel.url,
                       let item = AppFinder.appItem(from: url) {
                        selectApp(item)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // 실행 모드
            Text("launch.mode".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            Picker(selection: $config.mode) {
                ForEach(LaunchMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: config.mode) { _, _ in syncToStep() }

            // 인자 + URL 스킴
            Text("launch.args".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("--incognito", text: $config.args)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onChange(of: config.args) { _, _ in syncToStep() }

            Text("launch.url_scheme".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("obsidian://open?vault=main", text: $config.urlScheme)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onChange(of: config.urlScheme) { _, _ in syncToStep() }
        }
        .sectionCard()
    }

    /// 검색 결과 선택: 번들ID+경로 채우고 검색어 비우고 목록 접기 (사용자 지정 스펙).
    private func selectApp(_ app: AppItem) {
        config = LaunchAppSelection.selecting(app, in: config)
        if step.title.isEmpty {
            step.title = app.name
        }
        syncToStep()
        searchText = ""
        listCollapsed = true
    }

    /// 폼 상태를 step에 동기화 (launchConfig 우선, target 하위호환 유지).
    private func syncToStep() {
        LaunchAppSelection.apply(config, to: &step)
    }

    private func loadApps() {
        guard !didLoad else { return }
        // 폼 초기값: step → config (최초 1회)
        config = step.launchConfig ?? LaunchConfig.migrated(fromLegacyTarget: step.target)
        syncToStep()
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = AppFinder.installedApps().sorted { $0.name < $1.name }
            DispatchQueue.main.async {
                allApps = apps
                didLoad = true
                // 레거시 target이 있으면 매칭 앱의 path를 보정
                if config.path.isEmpty, let match = apps.first(where: { $0.bundleID == config.bundleID }) {
                    config.path = match.path
                    syncToStep()
                }
            }
        }
    }
}

/// 앱 선택 반영 로직 (순수 — 단위테스트 대상).
enum LaunchAppSelection {
    /// 앱 선택 → 기존 모드/인자/스킴은 유지하고 번들ID+경로만 교체.
    static func selecting(_ app: AppItem, in config: LaunchConfig) -> LaunchConfig {
        var next = config
        next.bundleID = app.bundleID
        next.path = app.path
        return next
    }

    /// 폼 상태 → step 반영.
    static func apply(_ config: LaunchConfig, to step: inout ShortcutStep) {
        step.launchConfig = config
        step.target = config.bundleID
    }
}
