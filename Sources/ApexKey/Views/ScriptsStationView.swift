import SwiftUI
import AppKit

/// 스크립트 탭 — 사용자 정의 셸 스크립트를 추가하고 글로벌 단축키로 실행
struct ScriptsStationView: View {
    @EnvironmentObject var store: ConfigStore
    @State private var showAddSheet = false
    @State private var addingActionType: ActionType?
    @State private var actionParam = ""
    @State private var recordingScript: ScriptItem?
    @State private var recordingActionType: ActionType?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if store.scripts.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 8) {
                            ForEach(store.scripts) { script in
                                scriptRow(script)
                            }
                        }
                    }
                    Spacer()
                    Divider()
                    VStack(spacing: 12) {
                        Text("새로운 액션").font(.headline)
                        HStack(spacing: 8) {
                            actionTypeButton("붙여넣기", systemImage: "clipboard", action: .paste)
                            actionTypeButton("대기", systemImage: "clock", action: .wait)
                            actionTypeButton("좌표 클릭", systemImage: "mousepointer", action: .coordinateClick)
                            actionTypeButton("입력 대기", systemImage: "pause.circle", action: .pauseUntilInput)
                        }
                    }
                    .padding(16)
                    Divider()
                    if !store.otherBindings.isEmpty {
                        VStack(spacing: 8) {
                            Text("등록된 액션").font(.headline)
                            ForEach(store.otherBindings) { binding in
                                otherBindingRow(binding)
                            }
                        }
                        .padding(16)
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 440, minHeight: 480)
        .sheet(isPresented: $showAddSheet) {
            AddScriptView { name, cmd in
                store.addScript(name: name, command: cmd)
            }
        }
        .sheet(item: $recordingScript) { script in
            HotKeyRecorderView(
                title: "\(script.name) — 글로벌 단축키",
                subtitle: "전역에서 실행",
                excludedCombo: store.scriptBindings(for: script.id).first?.combo,
                onTest: { combo in
                    let binding = HotKeyBinding(
                        combo: combo,
                        actionType: .script,
                        target: script.command,
                        title: script.name,
                        onlyWhenAppActive: false
                    )
                    ActionExecutor.shared.execute(binding)
                    return true
                }
            ) { combo in
                onRecord(combo: combo, script: script)
            }
            .environmentObject(store)
        }
        .sheet(item: $addingActionType) { actionType in
            addActionSheetContent(for: actionType)
        }
        .sheet(item: $recordingActionType) { type in
            let subtitle: String
            switch type {
            case .paste: subtitle = "붙여넣기: \(actionParam)"
            case .wait: subtitle = "대기: \(actionParam)초"
            case .coordinateClick: subtitle = "좌표: \(actionParam)"
            default: subtitle = "전역에서 실행"
            }
            return HotKeyRecorderView(
                title: type.displayName,
                subtitle: subtitle,
                onTest: { combo in
                    let binding = makeBinding(combo: combo, actionType: type)
                    ActionExecutor.shared.execute(binding)
                    return true
                }
            ) { combo in
                onRecordAction(combo: combo, actionType: type)
            }
            .environmentObject(store)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal")
                .frame(width: 36, height: 36)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("스크립트")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("셸 명령을 글로벌 단축키로 실행")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
                HStack(spacing: 4) {
                    Button {
                        store.startMacroRecording()
                    } label: {
                        Label("매크로 녹화", systemImage: "record")
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundColor(.red)
                    .disabled(store.isMacroRecording)
                    Button {
                        store.stopMacroRecording()
                    } label: {
                        Label("매크로 녹화 중지", systemImage: "stop")
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundColor(.white)
                    .background(Color.red)
                    .disabled(!store.isMacroRecording)
                    Button {
                        exportBindings()
                    } label: {
                        Label("내보내기", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderless)
                    .help("바인딩 내보내기")
                    Button {
                        importBindings()
                    } label: {
                        Label("가져오기", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderless)
                    .help("바인딩 가져오기")
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("스크립트 추가", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("스크립트 없음")
                .font(.headline)
            Text("\"스크립트 추가\"로 셸 명령을 등록하고 단축키를 할당하세요.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private func scriptRow(_ script: ScriptItem) -> some View {
        let bindings = store.scriptBindings(for: script.id)
        let comboText = bindings.first?.combo.displayString ?? ""
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: "terminal")
                    .foregroundColor(.accentColor)
                Text(script.name)
                    .font(.body.weight(.semibold))
                Spacer()
                if !comboText.isEmpty {
                    Text(comboText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.accentColor)
                }
                Button {
                    recordingScript = script
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .help("단축키 녹음")
                Button {
                    store.removeScript(script)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("삭제")
            }
            Text(script.command)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func otherBindingRow(_ binding: HotKeyBinding) -> some View {
        HStack(spacing: 10) {
            Image(systemName: binding.actionType.systemImage)
                .foregroundColor(.accentColor)
            Text(binding.title)
                .font(.body)
            Spacer()
            if !binding.combo.displayString.isEmpty {
                Text(binding.combo.displayString)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.accentColor)
            }
            Button {
                store.removeBinding(binding)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("삭제")
            Button {
                store.duplicate(binding)
            } label: {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("복제")
            Button {
                store.moveBinding(binding, direction: .up)
            } label: {
                Image(systemName: "chevron.up")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("위로")
            Button {
                store.moveBinding(binding, direction: .down)
            } label: {
                Image(systemName: "chevron.down")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("아래로")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func onRecord(combo: HotKeyCombo, script: ScriptItem) {
        guard !combo.isEmpty else { return }
        let existing = store.scriptBindings(for: script.id).first
        if let existing {
            let updated = HotKeyBinding(
                id: existing.id,
                combo: combo,
                actionType: .script,
                target: script.command,
                title: script.name,
                onlyWhenAppActive: false
            )
            store.removeBinding(existing)
            store.addBinding(updated)
        } else {
            store.addBinding(HotKeyBinding(
                combo: combo,
                actionType: .script,
                target: script.command,
                title: script.name,
                onlyWhenAppActive: false
            ))
        }
    }

    private func actionTypeButton(_ title: String, systemImage: String, action: ActionType) -> some View {
        Button {
            addingActionType = action
            actionParam = ""
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private func addActionSheetContent(for actionType: ActionType) -> some View {
        let isPause = actionType == .pauseUntilInput
        VStack(alignment: .leading, spacing: 16) {
            Text("\(actionType.displayName) 추가")
                .font(.headline)
            if !isPause {
                TextField(actionType == .paste ? "붙여넣을 텍스트" : actionType == .wait ? "초" : "x,y 좌표", text: $actionParam)
                    .textFieldStyle(.roundedBorder)
            }
            if isPause {
                Text("⌘⇧↩를 누르면 대기가 종료됩니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack {
                Button("취소") { addingActionType = nil }
                Spacer()
                Button("단축키 녹음") {
                    recordingActionType = actionType
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isPause && actionParam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    private func makeBinding(combo: HotKeyCombo, actionType: ActionType) -> HotKeyBinding {
        let target: String
        switch actionType {
        case .paste: target = actionParam.isEmpty ? "clipboard" : actionParam
        case .wait: target = actionParam.isEmpty ? "1.0" : actionParam
        case .coordinateClick: target = actionParam.isEmpty ? "0,0" : actionParam
        default: target = ""
        }
        return HotKeyBinding(
            combo: combo,
            actionType: actionType,
            target: target,
            title: actionType.displayName,
            onlyWhenAppActive: false
        )
    }

    private func onRecordAction(combo: HotKeyCombo, actionType: ActionType) {
        guard !combo.isEmpty else { return }
        store.addBinding(makeBinding(combo: combo, actionType: actionType))
    }

    private func exportBindings() {
        guard let data = store.exportBindings() else { return }
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["json"]
        panel.nameFieldStringValue = "apexkey_bindings.json"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                Logger.info("ScriptsStationView", "바인딩 내보내기: \(url.path)")
            } catch {
                Logger.error("E-UI-EXPORT-6001", "내보내기 실패: \(error.localizedDescription)")
            }
        }
    }

    private func importBindings() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["json"]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let count = store.importBindings(from: data)
                Logger.info("ScriptsStationView", "바인딩 가져오기: \(count)개")
            } catch {
                Logger.error("E-UI-IMPORT-6001", "가져오기 실패: \(error.localizedDescription)")
            }
        }
    }
}

/// 스크립트 추가 시트
private struct AddScriptView: View {
    var onAdd: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var command = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("스크립트 추가")
                .font(.headline)
            TextField("이름", text: $name)
                .textFieldStyle(.roundedBorder)
            Text("명령 (zsh)")
                .font(.caption)
                .foregroundColor(.secondary)
            TextEditor(text: $command)
                .font(.system(.body, design: .monospaced))
                .frame(height: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
            HStack {
                Button("취소") { dismiss() }
                Spacer()
                Button("추가") {
                    onAdd(name, command)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}