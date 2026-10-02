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
    case clipboard(ClipboardEntry)

    var id: String {
        switch self {
        case .command(let c): return "cmd-\(c.id)"
        case .shortcut(let s): return "shortcut-\(s.id.uuidString)"
        case .stepHit(let h): return "hit-\(h.id)"
        case .binding(let b): return "binding-\(b.id.uuidString)"
        case .app(let a): return "app-\(a.bundleID)"
        case .clipboard(let e): return "clip-\(e.id.uuidString)"
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
    /// 앱 기록 변경 시 섹션 갱신용 버전 (record/clear 후 증가)
    @State private var appRecentsVersion = 0
    /// 클립보드 기록 갱신용 버전
    @State private var clipVersion = 0
    @State private var lastClipCount = -1
    /// ⌥↩ 처리 시 TextField onSubmit 중복 실행 방지
    @State private var skipNextSubmit = false
    private let clipTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    private var isClipboardMode: Bool { store.paletteMode == .clipboard }
    private var clipHistory: ClipboardHistory { ClipboardMonitor.shared.history }

    private var isEmptyQuery: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 고정 명령 7종.
    private var commands: [PaletteCommand] {
        [
            PaletteCommand(id: "newShortcut", title: "palette.cmd.new_shortcut".localized, hint: "", icon: "plus"),
            PaletteCommand(id: "clipboard", title: "palette.cmd.clipboard".localized, hint: "⌘⇧V", icon: "doc.on.clipboard"),
            PaletteCommand(id: "openSettings", title: "palette.cmd.open_settings".localized, hint: "", icon: "gearshape"),
            PaletteCommand(id: "openPanel", title: "palette.cmd.open_panel".localized, hint: "⇧⌥A", icon: "macwindow"),
            PaletteCommand(id: "menuHUD", title: "palette.cmd.menu_hud".localized, hint: "⇧⌥S", icon: "menubar"),
            PaletteCommand(id: "repeatLast", title: "palette.cmd.repeat_last".localized, hint: "⌘⇧↩", icon: "repeat"),
            PaletteCommand(id: "quitApp", title: "palette.cmd.quit".localized, hint: "", icon: "power"),
        ]
    }

    private var recentShortcuts: [ShortcutItem] {
        guard isEmptyQuery else { return [] }
        let all = CommandPaletteFilter.recents(from: store.shortcuts)
        return PaletteWorkflowRank.visibleRecents(
            from: all,
            clearedAt: PaletteAppRecents.clearedAt()
        )
    }

    /// 최근 사용 혼합 (워크플로우 + 앱, 시각 내림차순, 최대 6) — 빈 입력 기본 화면용.
    private var mixedRecents: [PaletteRow] {
        guard isEmptyQuery else { return [] }
        _ = appRecentsVersion
        let appEntries = PaletteAppRecents.recents()
        var timed: [(Date, PaletteRow)] = recentShortcuts.map {
            (($0.lastRunAt ?? .distantPast), .shortcut($0))
        }
        for e in appEntries {
            timed.append((e.lastUsed, .app(AppItem(name: e.name, bundleID: e.bundleID, path: e.path))))
        }
        return timed.sorted { $0.0 > $1.0 }.prefix(6).map { $0.1 }
    }

    /// Instant Send 전송 대상 (최근 실행 우선) — 전송 모드용.
    private var sendShortcuts: [ShortcutItem] {
        guard store.paletteMode == .send else { return [] }
        let rec = CommandPaletteFilter.recents(from: store.shortcuts)
        let ids = Set(rec.map(\.id))
        return rec + store.shortcuts.filter { !ids.contains($0.id) }.sorted { $0.name < $1.name }
    }

    /// 자주 쓰는 워크플로우 (runCount 순, 최근과 중복 제외) — 빈 입력 기본 화면용.
    private var frequentWorkflows: [ShortcutItem] {
        guard isEmptyQuery else { return [] }
        let recentIDs = Set(recentShortcuts.map(\.id))
        return PaletteWorkflowRank.frequent(from: store.shortcuts, excluding: recentIDs)
    }

    /// 자주 쓰는 앱 (2회 이상 실행, 최근과 중복 제외) — 빈 입력 기본 화면용.
    private var frequentApps: [AppItem] {
        guard isEmptyQuery else { return [] }
        _ = appRecentsVersion
        let recentIDs = Set(PaletteAppRecents.recents().map(\.bundleID))
        return PaletteAppRecents.frequent()
            .filter { !recentIDs.contains($0.bundleID) }
            .prefix(5)
            .map { AppItem(name: $0.name, bundleID: $0.bundleID, path: $0.path) }
    }

    /// 빈 입력 + 실행 기록 없음 → 고정 6종 폴백 (레퍼런스 fallback, 패널이 비어 보이지 않게).
    private var fallbackCommands: [PaletteCommand] {
        guard isEmptyQuery else { return [] }
        return CommandPaletteFilter.fallbackCommands(all: commands, recents: recentShortcuts)
    }

    /// 빈 입력 기본 화면의 명령 섹션 — 항상 표시 (LiteRT식 기본 메뉴).
    private var emptyCommands: [PaletteCommand] {
        guard isEmptyQuery else { return [] }
        return commands
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

    /// 단일 선택 공간 (표시 순서: 최근 혼합/자주 쓰는 워크플로우/자주 쓰는 앱/명령/동작/단계내용/단축키/앱).
    private var rows: [PaletteRow] {
        if store.paletteMode == .send {
            _ = clipVersion
            let base = sendShortcuts
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let list = q.isEmpty ? base : CommandPaletteFilter.filterShortcuts(base, query: searchText)
            return list.map(PaletteRow.shortcut)
        }
        if isClipboardMode {
            _ = clipVersion
            return clipHistory.search(searchText).map(PaletteRow.clipboard)
        }
        if isEmptyQuery {
            return mixedRecents
                + frequentWorkflows.map(PaletteRow.shortcut)
                + frequentApps.map(PaletteRow.app)
                + emptyCommands.map(PaletteRow.command)
        }
        return commandRows.map(PaletteRow.command)
            + matchedShortcuts.map(PaletteRow.shortcut)
            + matchedSteps.map(PaletteRow.stepHit)
            + matchedBindings.map(PaletteRow.binding)
            + matchedApps.map(PaletteRow.app)
    }

    private var selectedID: String? {
        rows.indices.contains(selectedIndex) ? rows[selectedIndex].id : nil
    }

    // MARK: - 섹션 (body 타입체커 분할용)

    @ViewBuilder
    private var sendSections: some View {
        if let payload = store.sendPayload {
            VStack(alignment: .leading, spacing: 2) {
                Text("palette.send.from".localizedFormat(payload.sourceApp))
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                Text(String(payload.text.prefix(140)))
                    .font(.system(size: 12))
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
        }
        sectionLabel("palette.send.workflows".localized)
        ForEach(sendRows) { shortcut in
            shortcutRow(shortcut)
        }
    }

    /// 전송 모드 표시 목록 (검색 필터 적용).
    private var sendRows: [ShortcutItem] {
        rows.compactMap { row in
            if case .shortcut(let s) = row { return s }
            return nil
        }
    }

    @ViewBuilder
    private var clipboardSections: some View {
        let entries = clipHistory.search(searchText)
        let pinned = entries.filter { $0.pinned }
        let rest = entries.filter { !$0.pinned }
        if !pinned.isEmpty {
            sectionLabel("palette.section.pinned".localized)
            ForEach(pinned) { entry in
                clipRow(entry)
            }
        }
        if !rest.isEmpty {
            sectionLabel("palette.section.recent".localized)
            ForEach(rest) { entry in
                clipRow(entry)
            }
        }
    }

    @ViewBuilder
    private var emptyQuerySections: some View {
        if !mixedRecents.isEmpty {
            recentHeader
            ForEach(mixedRecents, id: \.id) { row in
                paletteRow(row, showRecency: true)
            }
        }
        if !frequentWorkflows.isEmpty {
            sectionLabel("palette.section.frequent_shortcuts".localized)
            ForEach(frequentWorkflows) { shortcut in
                shortcutRow(shortcut)
            }
        }
        if !frequentApps.isEmpty {
            sectionLabel("palette.section.frequent_apps".localized)
            ForEach(frequentApps) { app in
                appRow(app)
            }
        }
        if !emptyCommands.isEmpty {
            sectionLabel("palette.section.commands".localized)
            ForEach(emptyCommands) { cmd in
                commandRow(cmd)
            }
        }
    }

    @ViewBuilder
    private var searchSections: some View {
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
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    if store.paletteMode == .send {
                        sendSections
                    } else if isClipboardMode {
                        clipboardSections
                    } else if isEmptyQuery {
                        emptyQuerySections
                    } else {
                        searchSections
                    }
                    if rows.isEmpty {
                        Text(isClipboardMode ? "palette.clipboard.empty".localized : "palette.empty".localized)
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)
                            .padding(16)
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(maxHeight: isClipboardMode ? 310 : 340)
            if store.paletteMode == .send {
                Divider()
                Text("palette.send.hint".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            } else if isClipboardMode {
                Divider()
                Text("palette.clipboard.footer".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
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
            installClipKeyMonitor()
            if isClipboardMode {
                ClipboardMonitor.shared.refresh()
                lastClipCount = clipHistory.all().count
            }
        }
        .onDisappear {
            removeClipKeyMonitor()
            store.paletteMode = .normal
            store.sendPayload = nil
        }
        .onReceive(clipTimer) { _ in
            guard isClipboardMode else { return }
            let count = clipHistory.all().count
            if count != lastClipCount {
                lastClipCount = count
                clipVersion += 1
                selectedIndex = 0
            }
        }
        .onChange(of: searchText) { _, _ in selectedIndex = 0 }
        .onKeyPress(.upArrow) { moveSelection(by: -1) }
        .onKeyPress(.downArrow) { moveSelection(by: 1) }
        .onKeyPress(.escape) {
            store.showPalette = false
            return .handled
        }
        // ⌫ — 검색어 있을 땐 텍스트 편집에 양보, 비어 있을 때만 항목 삭제
        .onKeyPress(.delete) {
            guard isClipboardMode, searchText.isEmpty else { return .ignored }
            deleteSelectedClip()
            return .handled
        }
    }

    // MARK: - 클립보드 키 모니터 (⌘1–9/⌘P/⌥↩ — onKeyPress에 modifiers 오버로드가 없어 NSEvent로 처리)

    @State private var clipKeyMonitor: Any?

    private func installClipKeyMonitor() {
        guard clipKeyMonitor == nil else { return }
        let searchBinding = $searchText
        let indexBinding = $selectedIndex
        let versionBinding = $clipVersion
        clipKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // 로컬 모니터는 메인 스레드에서 호출되므로 MainActor 격리로 수행한다
            MainActor.assumeIsolated { () -> NSEvent? in
                guard store.paletteMode == .clipboard else { return event }
                let flags = event.modifierFlags
                let history = ClipboardMonitor.shared.history
                let clips: () -> [ClipboardEntry] = {
                    history.search(searchBinding.wrappedValue).prefix(9).map { $0 }
                }
                let pasteEntry: (ClipboardEntry) -> Void = { entry in
                    store.showPalette = false
                    DispatchQueue.global(qos: .userInitiated).async {
                        history.paste(entry)
                    }
                }
                // ⌥↩ — 복사만 (이벤트 삼켜 TextField submit 방지)
                if event.keyCode == 36, flags.contains(.option), !flags.contains(.command) {
                    let list = clips()
                    if indexBinding.wrappedValue < list.count {
                        let entry = list[indexBinding.wrappedValue]
                        store.showPalette = false
                        history.copy(entry)
                    }
                    return nil
                }
                guard flags.contains(.command), !flags.contains(.option) else { return event }
                // ⌘1–9 — 순서대로 붙여넣기
                if let chars = event.charactersIgnoringModifiers, chars.count == 1,
                   let n = Int(chars), (1...9).contains(n) {
                    let list = clips()
                    if n <= list.count { pasteEntry(list[n - 1]) }
                    return nil
                }
                // ⌘P — 고정 토글 (P keyCode 35)
                if event.keyCode == 35 {
                    let all = history.search(searchBinding.wrappedValue)
                    if indexBinding.wrappedValue < all.count {
                        let entry = all[indexBinding.wrappedValue]
                        history.setPinned(entry.id, pinned: !entry.pinned)
                        versionBinding.wrappedValue += 1
                    }
                    return nil
                }
                return event
            }
        }
    }

    private func removeClipKeyMonitor() {
        if let m = clipKeyMonitor {
            NSEvent.removeMonitor(m)
            clipKeyMonitor = nil
        }
    }

    // MARK: - 컴포넌트 (레퍼런스 행 스펙: 아이콘 12+제목 13+힌트 캡션, 선택 시 둥근강조)

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(theme.secondaryText)
            TextField(isClipboardMode ? "palette.clipboard.search".localized : "palette.search.placeholder".localized, text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($isSearchFocused)
                .onSubmit {
                    if skipNextSubmit {
                        skipNextSubmit = false
                        return
                    }
                    runSelected()
                }
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(.plain)
                .help("palette.clear".localized)
            }
            Text("palette.esc_key".localized)
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

    /// 최근 사용 헤더 + 지우기 (LiteRT식).
    private var recentHeader: some View {
        HStack {
            Text("palette.section.recent".localized)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.secondaryText)
            Spacer()
            Button("palette.clear".localized) {
                PaletteAppRecents.clear()
                appRecentsVersion += 1
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundColor(theme.secondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    /// 혼합 최근 행 렌더러.
    @ViewBuilder
    private func paletteRow(_ row: PaletteRow, showRecency: Bool = false) -> some View {
        switch row {
        case .shortcut(let s): shortcutRow(s, showRecency: showRecency)
        case .app(let a): appRow(a)
        case .command(let c): commandRow(c)
        case .binding(let b): bindingRow(b)
        case .stepHit(let h): stepHitRow(h)
        case .clipboard(let e): clipRow(e)
        }
    }

    /// 클립보드 기록 행 — 텍스트 미리보기 / 이미지 썸네일 + 선택 시 확대.
    @ViewBuilder
    private func clipRow(_ entry: ClipboardEntry) -> some View {
        let isSelected = selectedID == "clip-\(entry.id.uuidString)"
        Button { runClip(entry) } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    clipIcon(entry)
                    VStack(alignment: .leading, spacing: 1) {
                        Self.highlightedTitle(clipTitle(entry), query: searchText)
                            .font(.system(size: 13))
                            .lineLimit(1)
                        Text(clipMeta(entry))
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    if entry.pinned {
                        Text("📌")
                            .font(.caption)
                    }
                    if let n = clipNumber(entry) {
                        Text("⌘\(n)")
                            .font(.caption)
                            .foregroundColor(theme.secondaryText.opacity(0.6))
                    }
                }
                // 선택된 이미지 행은 확대 미리보기 (Quick Look 대신 인라인)
                if isSelected, entry.kind == .image,
                   let big = clipHistory.fullImage(for: entry) ?? clipHistory.thumbnail(for: entry) {
                    Image(nsImage: big)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.leading, 28)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.3))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private func clipIcon(_ entry: ClipboardEntry) -> some View {
        switch entry.kind {
        case .text:
            Image(systemName: "doc.text")
                .font(.system(size: 12))
                .foregroundColor(theme.secondaryText)
                .frame(width: 20)
        case .image:
            if let thumb = clipHistory.thumbnail(for: entry) {
                Image(nsImage: thumb)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
                    .frame(width: 20)
            }
        case .file:
            Image(systemName: "doc")
                .font(.system(size: 12))
                .foregroundColor(theme.secondaryText)
                .frame(width: 20)
        }
    }

    private func clipTitle(_ entry: ClipboardEntry) -> String {
        switch entry.kind {
        case .text: return entry.text.components(separatedBy: .newlines).first ?? entry.text
        case .image:
            let size = entry.byteCount >= 1024 * 1024
                ? String(format: "%.1fMB", Double(entry.byteCount) / 1048576.0)
                : "\(entry.byteCount / 1024)KB"
            return "palette.clipboard.image_fmt".localizedFormat(entry.dimensions, size)
        case .file: return entry.text
        }
    }

    private func clipMeta(_ entry: ClipboardEntry) -> String {
        let ago = entry.createdAt.formatted(.relative(presentation: .named))
        return entry.sourceApp.isEmpty ? ago : "\(entry.sourceApp) · \(ago)"
    }

    /// 표시 순서상 번호 (⌘1–9) — 현재 rows 기준.
    private func clipNumber(_ entry: ClipboardEntry) -> Int? {
        let clips = rows.compactMap { row -> ClipboardEntry? in
            if case .clipboard(let e) = row { return e }
            return nil
        }
        guard let i = clips.firstIndex(where: { $0.id == entry.id }), i < 9 else { return nil }
        return i + 1
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
                Group {
                    if let nsImg = AppIconCache.icon(for: app) {
                        Image(nsImage: nsImg)
                            .resizable()
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "app.badge")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondaryText)
                    }
                }
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
                if selectedID == "app-\(app.bundleID)" {
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
        case .shortcut(let s):
            if store.paletteMode == .send { runSendShortcut(s) } else { runShortcut(s) }
        case .stepHit(let h): runStepHit(h)
        case .binding(let b): runBinding(b)
        case .app(let a): runApp(a)
        case .clipboard(let e): runClip(e)
        }
    }

    /// Instant Send 전송 — 선택 워크플로우에 캡처 텍스트를 입력으로 실행.
    private func runSendShortcut(_ shortcut: ShortcutItem) {
        guard let payload = store.sendPayload else { return }
        store.showPalette = false
        store.sendPayload = nil
        guard let current = store.shortcuts.first(where: { $0.id == shortcut.id }) else { return }
        store.executeShortcutWithInput(current, input: .text(payload.text))
    }

    // MARK: - 클립보드 실행

    /// ↩ — 되돌리고 활성 앱에 붙여넣기.
    private func runClip(_ entry: ClipboardEntry) {
        store.showPalette = false
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = ClipboardMonitor.shared.history.paste(entry)
            Logger.info("Palette", "클립보드 붙여넣기 \(ok ? "성공" : "실패"): \(entry.kind.rawValue)")
        }
    }

    /// ⌫ — 삭제.
    private func deleteSelectedClip() {
        guard let entry = selectedClipEntry() else { return }
        clipHistory.remove(entry.id)
        clipVersion += 1
        selectedIndex = max(0, min(selectedIndex, rows.count - 2))
    }

    private func selectedClipEntry() -> ClipboardEntry? {
        guard rows.indices.contains(selectedIndex) else { return nil }
        if case .clipboard(let e) = rows[selectedIndex] { return e }
        return nil
    }

    private func runCommand(_ id: String) {
        Logger.info("Palette", "명령: \(id)")
        switch id {
        case "clipboard":
            // 커맨드 팔레트 안에서 클립보드 모드로 전환 (닫지 않음)
            store.paletteMode = .clipboard
            searchText = ""
            selectedIndex = 0
            ClipboardMonitor.shared.refresh()
            lastClipCount = ClipboardMonitor.shared.history.all().count
            return
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
        PaletteAppRecents.record(bundleID: app.bundleID, name: app.name, path: app.path)
        AppSwitcher.activate(bundleID: app.bundleID, path: app.path)
    }
}
