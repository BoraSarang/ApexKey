import SwiftUI
import AppKit

/// 동작(단축어) 스테이션 — 여러 단계(행위)를 하나의 동작으로 만들고 실행·단축키 지정
struct ShortcutStationView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme

    @State private var creatingShortcut = false
    @State private var newShortcutName = ""
    @State private var recordingComboFor: ShortcutItem?
    @State private var runningShortcutID: UUID?
    @State private var pendingDeletion: ShortcutItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("ui.station.intro".localized)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        creatingShortcut = true
                        newShortcutName = ""
                    } label: {
                        Label("ui.station.new_shortcut".localized, systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)

                    if store.shortcuts.isEmpty {
                        Text("ui.station.empty".localized)
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            VStack(spacing: 8) {
                                ForEach(store.shortcuts) { shortcut in
                                    shortcutCard(shortcut)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(16)
            }
        }
        .frame(minWidth: 440, minHeight: 480)
        .background(theme.primaryBackground)
        // 새 동작 이름 입력
        .sheet(isPresented: $creatingShortcut) {
            VStack(spacing: 16) {
                Text("ui.station.new_shortcut".localized)
                    .font(.headline)
                TextField("ui.station.name_placeholder".localized, text: $newShortcutName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                    .onSubmit { confirmCreate() }
                HStack {
                    Button("ui.cancel".localized) { creatingShortcut = false }
                    Spacer()
                    Button("ui.station.create".localized) { confirmCreate() }
                        .buttonStyle(.borderedProminent)
                        .disabled(newShortcutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(24)
            .frame(width: 360, alignment: .topLeading)
        }
        // 단축키 녹음
        .sheet(item: $recordingComboFor) { shortcut in
            HotKeyRecorderView(
                title: "ui.station.hotkey_title".localizedFormat(shortcut.name),
                subtitle: "ui.station.hotkey_subtitle".localizedFormat(shortcut.steps.count),
                excludedCombo: shortcut.combo.isEmpty ? nil : shortcut.combo,
                onTest: { combo in
                    let testShortcut = ShortcutItem(
                        id: shortcut.id,
                        name: shortcut.name,
                        steps: shortcut.steps,
                        combo: combo
                    )
                    DispatchQueue.global(qos: .userInitiated).async {
                        ActionExecutor.shared.execute(testShortcut)
                    }
                    return true
                }
            ) { combo in
                store.setShortcutCombo(shortcut, combo: combo)
            }
            .environmentObject(store)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up.fill")
                .frame(width: 36, height: 36)
                .font(.title3)
                .foregroundColor(theme.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("ui.shortcut".localized)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("ui.station.intro2".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func shortcutCard(_ shortcut: ShortcutItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up")
                    .foregroundColor(theme.accentColor)
                HStack(spacing: 6) {
                    Text(shortcut.name)
                        .font(.body)
                        .fontWeight(.medium)
                    Text("ui.editor.steps_count".localizedFormat(shortcut.steps.count))
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()
                if runningShortcutID == shortcut.id {
                    ProgressView()
                        .controlSize(.small)
                }
                // 단계 미리보기 — 오른쪽 정렬, 너비 제한으로 잘림
                if !shortcut.steps.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(shortcut.steps.prefix(3).enumerated()), id: \.element.id) { index, step in
                            HStack(spacing: 3) {
                                Image(systemName: step.type.systemImage)
                                Text(step.summary)
                                    .lineLimit(1)
                            }
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(theme.tertiaryBackground.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            if index < min(shortcut.steps.count, 3) - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(theme.secondaryText)
                            }
                        }
                        if shortcut.steps.count > 3 {
                            Text("+\(shortcut.steps.count - 3)")
                                .font(.caption2)
                                .foregroundColor(theme.secondaryText)
                        }
                    }
                    .frame(maxWidth: 260, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("ui.station.no_steps".localized)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
            }

            Divider()

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Button {
                        runShortcut(shortcut)
                    } label: {
                        Label("ui.run".localized, systemImage: "play.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("ui.station.run_all".localized)
                    if !shortcut.combo.isEmpty {
                        Text(shortcut.combo.displayString)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(theme.accentColor)
                    }
                }

                Button {
                    recordingComboFor = shortcut
                } label: {
                    Label(shortcut.combo.isEmpty ? "ui.station.assign_hotkey".localized : "ui.appdetail.change_hotkey".localized, systemImage: "keyboard")
                }
                .buttonStyle(.borderless)
                .help("ui.station.assign_hotkey_help".localized)

                Button {
                    openEditor(for: shortcut)
                } label: {
                    Label("ui.station.edit_steps".localized, systemImage: "list.number")
                }
                .buttonStyle(.borderless)
                .help("ui.station.edit_steps_help".localized)

                Spacer()

                Button {
                    pendingDeletion = shortcut
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(theme.errorColor)
                }
                .buttonStyle(.borderless)
                .help("ui.delete".localized)
                .confirmationDialog(
                    "ui.station.delete_alert_title".localizedFormat(shortcut.name),
                    isPresented: Binding(
                        get: { pendingDeletion?.id == shortcut.id },
                        set: { if !$0 { pendingDeletion = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button("ui.delete".localized, role: .destructive) {
                        if let s = pendingDeletion {
                            store.removeShortcut(s)
                        }
                        pendingDeletion = nil
                    }
                    Button("ui.cancel".localized, role: .cancel) { pendingDeletion = nil }
                } message: {
                    Text("ui.station.delete_alert_message".localizedFormat(shortcut.steps.count))
                }
            }
        }
        .padding(8)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func confirmCreate() {
        let name = newShortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let shortcut = store.addShortcut(name: name) {
            openEditor(for: shortcut)
        }
        creatingShortcut = false
    }

    /// 동작 편집기를 독립 창으로 표시 (메인 창 크기에 얽매이지 않도록 AppDelegate 경유)
    private func openEditor(for shortcut: ShortcutItem) {
        (NSApp.delegate as? AppDelegate)?.showEditor(for: shortcut)
    }

    private func runShortcut(_ shortcut: ShortcutItem) {
        guard runningShortcutID == nil else { return }
        runningShortcutID = shortcut.id
        DispatchQueue.global(qos: .userInitiated).async {
            ActionExecutor.shared.execute(shortcut)
            DispatchQueue.main.async {
                runningShortcutID = nil
            }
        }
    }
}

/// 동작 편집기용 재귀 메뉴 선택 노드 — 잎(실행 가능 항목)만 선택 가능
private struct MenuChoiceNode: View {
    let item: MenuItem
    let selected: MenuItem?
    let onSelect: (MenuItem) -> Void

    @Environment(\.theme) private var theme
    @State private var isExpanded = true

    var body: some View {
        if item.isSeparator {
            Divider()
        } else if !item.children.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(spacing: 2) {
                    ForEach(item.children) { child in
                        MenuChoiceNode(item: child, selected: selected, onSelect: onSelect)
                    }
                }
                .padding(.leading, 8)
            } label: {
                HStack(spacing: 8) {
                    Text(item.title.isEmpty ? "ui.appdetail.submenu".localized : item.title)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(theme.secondaryText)
                }
                .padding(.vertical, 3)
                .contentShape(Rectangle())
            }
        } else {
            Button {
                onSelect(item)
            } label: {
                HStack(spacing: 8) {
                    Text(item.title.isEmpty ? "ui.station.separator".localized : item.title)
                        .lineLimit(1)
                    Spacer()
                    if !item.keyEquivalentDisplay.isEmpty {
                        Text(item.keyEquivalentDisplay)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(theme.secondaryText)
                    }
                    if selected?.id == item.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(theme.successColor)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(item.title)
        }
    }
}

