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
                    Text("앱 열기, 키 입력, 스크립트, 붙여넣기 등을 단계로 쌓아 하나의 동작으로 만듭니다. 실행 버튼으로 테스트하고 단축키를 지정할 수 있습니다.")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        creatingShortcut = true
                        newShortcutName = ""
                    } label: {
                        Label("새 동작", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)

                    if store.shortcuts.isEmpty {
                        Text("등록된 동작이 없습니다. '새 동작'으로 시작하세요.")
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
                Text("새 동작")
                    .font(.headline)
                TextField("이름 (예: 작업 시작)", text: $newShortcutName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                    .onSubmit { confirmCreate() }
                HStack {
                    Button("취소") { creatingShortcut = false }
                    Spacer()
                    Button("만들기") { confirmCreate() }
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
                title: "\(shortcut.name) 실행 단축키",
                subtitle: "이 단축키를 누르면 전체 \(shortcut.steps.count)단계가 순서대로 실행됩니다",
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
                Text("동작")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("여러 단계를 하나로 묶어 실행·단축키 지정")
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
                    Text("\(shortcut.steps.count)단계")
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
                    Text("단계 없음")
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
                        Label("실행", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("전체 단계를 순서대로 실행 (테스트)")
                    if !shortcut.combo.isEmpty {
                        Text(shortcut.combo.displayString)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(theme.accentColor)
                    }
                }

                Button {
                    recordingComboFor = shortcut
                } label: {
                    Label(shortcut.combo.isEmpty ? "단축키 지정" : "단축키 변경", systemImage: "keyboard")
                }
                .buttonStyle(.borderless)
                .help("글로벌 실행 단축키 지정")

                Button {
                    openEditor(for: shortcut)
                } label: {
                    Label("단계 편집", systemImage: "list.number")
                }
                .buttonStyle(.borderless)
                .help("단계 추가·정렬·삭제")

                Spacer()

                Button {
                    pendingDeletion = shortcut
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(theme.errorColor)
                }
                .buttonStyle(.borderless)
                .help("삭제")
                .confirmationDialog(
                    "‘\(shortcut.name)’ 동작을 삭제할까요?",
                    isPresented: Binding(
                        get: { pendingDeletion?.id == shortcut.id },
                        set: { if !$0 { pendingDeletion = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button("삭제", role: .destructive) {
                        if let s = pendingDeletion {
                            store.removeShortcut(s)
                        }
                        pendingDeletion = nil
                    }
                    Button("취소", role: .cancel) { pendingDeletion = nil }
                } message: {
                    Text("\(shortcut.steps.count)개 단계와 설정된 단축키가 함께 삭제됩니다. 되돌릴 수 없습니다.")
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
                    Text(item.title.isEmpty ? "(하위 메뉴)" : item.title)
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
                    Text(item.title.isEmpty ? "(분리자)" : item.title)
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

