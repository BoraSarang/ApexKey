import AppKit
import SwiftUI

/// 고정 명령 1건 (레퍼런스 PaletteCommand): id 기준 실행.
struct PaletteCommand: Identifiable, Hashable {
    let id: String
    let title: String
    let hint: String
    var icon: String = ""
}

/// 팔레트 행 — 명령/동작/단계적중/단축키/앱 단일 선택 공간.
/// 레퍼런스(LiteRT-LM Studio PaletteView): 섹션 + 최근 실행 + ↑↓/Enter/Esc.
enum PaletteRow: Identifiable, Hashable {
    case command(PaletteCommand)
    case shortcut(ShortcutItem)
    case stepHit(StepSearchHit)
    case binding(HotKeyBinding)
    case app(AppItem)

    var id: String {
        switch self {
        case .command(let c): return "cmd-\(c.id)"
        case .shortcut(let s): return "shortcut-\(s.id.uuidString)"
        case .stepHit(let h): return "hit-\(h.id)"
        case .binding(let b): return "binding-\(b.id.uuidString)"
        case .app(let a): return "app-\(a.id.uuidString)"
        }
    }
}

/// 단계 내용 검색 적중 1건 (레퍼런스 ChatSearchHit 대응): 동작+단계 위치+미리보기.
struct StepSearchHit: Identifiable, Hashable {
    var id: String { "\(shortcutID.uuidString)-\(stepID.uuidString)" }
    let shortcutID: UUID
    let shortcutName: String
    let stepID: UUID
    let stepTitle: String
    let preview: String
}

/// 팔레트 필터 (순수 함수 — 단위테스트 대상).
enum CommandPaletteFilter {
    static let maxRecents = 5
    static let maxApps = 20
    static let maxStepHits = 8
    static let minStepQueryLength = 2

    /// 최근 실행 동작 (lastRunAt 내림차순, 최대 5).
    static func recents(from shortcuts: [ShortcutItem], max: Int = maxRecents) -> [ShortcutItem] {
        shortcuts
            .filter { $0.lastRunAt != nil }
            .sorted { ($0.lastRunAt ?? .distantPast) > ($1.lastRunAt ?? .distantPast) }
            .prefix(max)
            .map { $0 }
    }

    /// 빈 입력 폴백 판정 (순수 — 테스트 대상): 실행 기록 없으면 고정 명령 표시.
    static func fallbackCommands(all: [PaletteCommand], recents: [ShortcutItem]) -> [PaletteCommand] {
        recents.isEmpty ? all : []
    }

    /// 고정 명령 필터 (빈 질의면 빈 배열 — 레퍼런스와 동일).
    static func filterCommands(_ commands: [PaletteCommand], query: String) -> [PaletteCommand] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return commands.filter { PaletteMatch.matchesRanges(text: $0.title, query: q) }
    }

    /// 동작 이름 필터.
    static func filterShortcuts(_ shortcuts: [ShortcutItem], query: String) -> [ShortcutItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return shortcuts
            .filter { PaletteMatch.matchesRanges(text: $0.name, query: q) }
            .sorted { $0.name < $1.name }
    }

    /// 동작 단계 내용 검색 (2자 이상, 최대 8건, 최근 수정순).
    /// 레퍼런스 ChatSearch 대응: 단계 제목/대상/메모 매칭 + 전후 20자 미리보기.
    static func filterSteps(_ shortcuts: [ShortcutItem], query: String,
                            maxHits: Int = maxStepHits) -> [StepSearchHit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= minStepQueryLength else { return [] }
        var hits: [StepSearchHit] = []
        let ordered = shortcuts.sorted { $0.modifiedAt > $1.modifiedAt }
        for shortcut in ordered {
            for step in shortcut.steps {
                let body = [step.title, step.target, step.note ?? "", step.type.displayName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                guard PaletteMatch.matchesRanges(text: body, query: q) else { continue }
                hits.append(StepSearchHit(
                    shortcutID: shortcut.id,
                    shortcutName: shortcut.name,
                    stepID: step.id,
                    stepTitle: step.title.isEmpty ? step.type.displayName : step.title,
                    preview: PaletteMatch.contextPreview(body, query: q)
                ))
                if hits.count >= maxHits { return hits }
            }
        }
        return hits
    }

    /// 단축키 필터 (제목/액션명/조합).
    static func filterBindings(_ bindings: [HotKeyBinding], query: String) -> [HotKeyBinding] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return bindings.filter {
            PaletteMatch.matchesRanges(text: $0.title, query: q)
                || PaletteMatch.matchesRanges(text: $0.actionType.displayName, query: q)
                || $0.combo.displayString.lowercased().contains(q)
        }.sorted { $0.title < $1.title }
    }

    /// 설치 앱 필터 (이름 + 번들ID 부분일치).
    static func filterApps(_ apps: [AppItem], query: String, max: Int = maxApps) -> [AppItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return apps.filter {
            PaletteMatch.matchesRanges(text: $0.name, query: q)
                || $0.bundleID.lowercased().contains(q.lowercased())
        }
        .sorted { $0.name < $1.name }
        .prefix(max)
        .map { $0 }
    }
}

/// Spotlight식 명령 팔레트 (⌘⌥K) — 검색창 + 섹션(최근 실행/명령/동작/단축키/앱) + 초성 매칭.
/// ↑↓ 이동(순환)·Enter 실행·Esc 닫기.
struct CommandPaletteView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme
    @FocusState private var isSearchFocused: Bool
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var allApps: [AppItem] = []

    private var isEmptyQuery: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 고정 명령 6종.
    private var commands: [PaletteCommand] {
        [
            PaletteCommand(id: "newShortcut", title: "palette.cmd.new_shortcut".localized, hint: "", icon: "plus"),
            PaletteCommand(id: "openSettings", title: "palette.cmd.open_settings".localized, hint: "", icon: "gearshape"),
            PaletteCommand(id: "openPanel", title: "palette.cmd.open_panel".localized, hint: "⇧⌥A", icon: "macwindow"),
            PaletteCommand(id: "menuHUD", title: "palette.cmd.menu_hud".localized, hint: "⇧⌥S", icon: "menubar"),
            PaletteCommand(id: "repeatLast", title: "palette.cmd.repeat_last".localized, hint: "⌘⇧↩", icon: "repeat"),
            PaletteCommand(id: "quitApp", title: "palette.cmd.quit".localized, hint: "", icon: "power"),
        ]
    }

    private var recentShortcuts: [ShortcutItem] {
        guard isEmptyQuery else { return [] }
        return CommandPaletteFilter.recents(from: store.shortcuts)
    }

    /// 빈 입력 + 실행 기록 없음 → 고정 6종 폴백 (레퍼런스 fallback, 패널이 비어 보이지 않게).
    private var fallbackCommands: [PaletteCommand] {
        guard isEmptyQuery else { return [] }
        return CommandPaletteFilter.fallbackCommands(all: commands, recents: recentShortcuts)
    }

    /// 명령 행 (폴백 + 매칭 합산).
    private var commandRows: [PaletteCommand] {
        fallbackCommands + matchedCommands
    }

    private var matchedCommands: [PaletteCommand] {
        CommandPaletteFilter.filterCommands(commands, query: searchText)
    }

    private var matchedShortcuts: [ShortcutItem] {
        CommandPaletteFilter.filterShortcuts(store.shortcuts, query: searchText)
    }

    private var matchedBindings: [HotKeyBinding] {
        CommandPaletteFilter.filterBindings(store.bindings, query: searchText)
    }

    private var matchedApps: [AppItem] {
        CommandPaletteFilter.filterApps(allApps, query: searchText)
    }

    private var matchedSteps: [StepSearchHit] {
        CommandPaletteFilter.filterSteps(store.shortcuts, query: searchText)
    }

    /// 단일 선택 공간 (표시 순서: 최근 실행/명령/동작/단계내용/단축키/앱).
    private var rows: [PaletteRow] {
        recentShortcuts.map(PaletteRow.shortcut)
            + commandRows.map(PaletteRow.command)
            + matchedShortcuts.map(PaletteRow.shortcut)
            + matchedSteps.map(PaletteRow.stepHit)
            + matchedBindings.map(PaletteRow.binding)
            + matchedApps.map(PaletteRow.app)
    }

    private var selectedID: String? {
        rows.indices.contains(selectedIndex) ? rows[selectedIndex].id : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !recentShortcuts.isEmpty {
                        sectionLabel("palette.section.recent".localized)
                        ForEach(recentShortcuts) { shortcut in
                            shortcutRow(shortcut, showRecency: true)
                        }
                    }
                    if !commandRows.isEmpty {
                        sectionLabel("palette.section.commands".localized)
                        ForEach(commandRows) { cmd in
                            commandRow(cmd)
                        }
                    }
                    if !matchedShortcuts.isEmpty {
                        sectionLabel("palette.section.shortcuts".localized)
                        ForEach(matchedShortcuts) { shortcut in
                            shortcutRow(shortcut)
                        }
                    }
                    if !matchedSteps.isEmpty {
                        sectionLabel("palette.section.steps".localized)
                        ForEach(matchedSteps) { hit in
                            stepHitRow(hit)
                        }
                    }
                    if !matchedBindings.isEmpty {
                        sectionLabel("palette.section.bindings".localized)
                        ForEach(matchedBindings) { binding in
                            bindingRow(binding)
                        }
                    }
                    if !matchedApps.isEmpty {
                        sectionLabel("palette.section.apps".localized)
                        ForEach(matchedApps) { app in
                            appRow(app)
                        }
                    }
                    if rows.isEmpty {
                        Text("palette.empty".localized)
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)
                            .padding(16)
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(maxHeight: 320)
        }
        .frame(width: 560)
        .background(theme.primaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 12)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.secondaryBorder)
        }
        .onAppear {
            isSearchFocused = true
            loadApps()
        }
        .onChange(of: searchText) { _, _ in selectedIndex = 0 }
        .onKeyPress(.upArrow) { moveSelection(by: -1) }
        .onKeyPress(.downArrow) { moveSelection(by: 1) }
        .onKeyPress(.escape) {
            store.showPalette = false
            return .handled
        }
    }

    // MARK: - 컴포넌트 (레퍼런스 행 스펙: 아이콘 12+제목 13+힌트 캡션, 선택 시 둥근강조)

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(theme.secondaryText)
            TextField("palette.search.placeholder".localized, text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($isSearchFocused)
                .onSubmit { runSelected() }
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(.plain)
                .help("palette.clear".localized)
            }
            Text("esc")
                .font(.caption)
                .foregroundColor(theme.secondaryText.opacity(0.6))
        }
        .padding(12)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
    }

    private func commandRow(_ cmd: PaletteCommand) -> some View {
        Button { runCommand(cmd.id) } label: {
            HStack(spacing: 8) {
                if !cmd.icon.isEmpty {
                    Image(systemName: cmd.icon)
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                        .frame(width: 20)
                }
                Self.highlightedTitle(cmd.title, query: searchText)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer()
                if !cmd.hint.isEmpty {
                    Text(cmd.hint)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText.opacity(0.6))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if selectedID == "cmd-\(cmd.id)" {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.3))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }

    private func shortcutRow(_ shortcut: ShortcutItem, showRecency: Bool = false) -> some View {
        Button { runShortcut(shortcut) } label: {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Self.highlightedTitle(shortcut.name, query: searchText)
                        .font(.system(size: 13))
                        .lineLimit(1)
                    if showRecency {
                        Text(shortcut.lastRunFormatted)
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)
                    }
                }
                Spacer()
                Text(shortcutHint(shortcut))
                    .font(.caption)
                    .foregroundColor(theme.secondaryText.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if selectedID == "shortcut-\(shortcut.id.uuidString)" {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.3))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }

    /// 단계 내용 적중 행 (2줄: 동작명+단계 / 미리보기).
    private func stepHitRow(_ hit: StepSearchHit) -> some View {
        Button { runStepHit(hit) } label: {
            HStack(spacing: 8) {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(hit.shortcutName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Self.highlightedTitle(hit.preview, query: searchText)
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if selectedID == "hit-\(hit.id)" {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.3))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }

    private func shortcutHint(_ shortcut: ShortcutItem) -> String {
        if !shortcut.combo.displayString.isEmpty { return shortcut.combo.displayString }
        return "palette.steps_fmt".localizedFormat(shortcut.steps.count)
    }

    private func bindingRow(_ binding: HotKeyBinding) -> some View {
        Button { runBinding(binding) } label: {
            HStack(spacing: 8) {
                Image(systemName: binding.actionType.systemImage)
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Self.highlightedTitle(binding.title, query: searchText)
                        .font(.system(size: 13))
                        .lineLimit(1)
                    Text(binding.actionType.displayName)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()
                if !binding.combo.displayString.isEmpty {
                    Text(binding.combo.displayString)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(theme.secondaryText.opacity(0.6))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if selectedID == "binding-\(binding.id.uuidString)" {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.3))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }

    private func appRow(_ app: AppItem) -> some View {
        Button { runApp(app) } label: {
            HStack(spacing: 8) {
                Image(systemName: "app.badge")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
                    .frame(width: 20)
                Self.highlightedTitle(app.name, query: searchText)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer()
                Text(app.bundleID)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if selectedID == "app-\(app.id.uuidString)" {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.3))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }

    /// 매칭 구간 하이라이트 (범위 기반 — 초성 매칭도 굵게).
    nonisolated static func highlightedTitle(_ title: String, query: String) -> Text {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty,
              let ranges = PaletteMatch.matchRanges(in: title, query: q),
              !ranges.isEmpty else {
            return Text(title)
        }
        var parts: [Text] = []
        var cur = title.startIndex
        for r in ranges {
            if cur < r.lowerBound { parts.append(Text(title[cur ..< r.lowerBound])) }
            parts.append(Text(title[r]).bold().foregroundColor(.accentColor))
            cur = r.upperBound
        }
        if cur < title.endIndex { parts.append(Text(title[cur...])) }
        guard let first = parts.first else { return Text(title) }
        return parts.dropFirst().reduce(first, +)
    }

    // MARK: - 데이터

    private func loadApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = AppFinder.installedApps().sorted { $0.name < $1.name }
            DispatchQueue.main.async { allApps = apps }
        }
    }

    // MARK: - 선택·실행

    private func moveSelection(by delta: Int) -> KeyPress.Result {
        guard !rows.isEmpty else { return .handled }
        selectedIndex = (selectedIndex + delta + rows.count) % rows.count
        return .handled
    }

    private func runSelected() {
        guard rows.indices.contains(selectedIndex) else { return }
        switch rows[selectedIndex] {
        case .command(let c): runCommand(c.id)
        case .shortcut(let s): runShortcut(s)
        case .stepHit(let h): runStepHit(h)
        case .binding(let b): runBinding(b)
        case .app(let a): runApp(a)
        }
    }

    private func runCommand(_ id: String) {
        Logger.info("Palette", "명령: \(id)")
        switch id {
        case "newShortcut":
            if let created = store.addShortcut(name: "palette.cmd.new_shortcut.name".localized) {
                store.showPalette = false
                (NSApp.delegate as? AppDelegate)?.showEditor(for: created)
            }
        case "openSettings":
            store.showPalette = false
            NotificationCenter.default.post(name: .openSettings, object: nil)
        case "openPanel":
            store.showPalette = false
            NotificationCenter.default.post(name: .togglePanel, object: nil)
        case "menuHUD":
            store.showPalette = false
            NotificationCenter.default.post(name: .toggleMenuHUD, object: nil)
        case "repeatLast":
            store.showPalette = false
            store.repeatLastBinding()
        case "quitApp":
            NSApp.terminate(nil)
        default:
            break
        }
    }

    private func runShortcut(_ shortcut: ShortcutItem) {
        store.showPalette = false
        guard let current = store.shortcuts.first(where: { $0.id == shortcut.id }) else { return }
        store.executeShortcutStats(current)
    }

    /// 단계 적중 실행: 편집기를 열고 해당 단계 선택.
    private func runStepHit(_ hit: StepSearchHit) {
        store.showPalette = false
        guard let current = store.shortcuts.first(where: { $0.id == hit.shortcutID }) else { return }
        (NSApp.delegate as? AppDelegate)?.showEditor(for: current, selectedStepID: hit.stepID)
    }

    private func runBinding(_ binding: HotKeyBinding) {
        store.executeBinding(binding)
    }

    private func runApp(_ app: AppItem) {
        store.showPalette = false
        AppSwitcher.activate(bundleID: app.bundleID, path: app.path)
    }
}
