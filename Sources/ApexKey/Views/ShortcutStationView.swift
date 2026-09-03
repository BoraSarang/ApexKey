import SwiftUI
import AppKit

/// 동작(단축어) 스테이션 — 여러 단계(행위)를 하나의 동작으로 만들고 실행·단축키 지정
struct ShortcutStationView: View {
    @EnvironmentObject var store: ConfigStore

    @State private var creatingShortcut = false
    @State private var newShortcutName = ""
    @State private var editingShortcut: ShortcutItem?
    @State private var recordingComboFor: ShortcutItem?
    @State private var runningShortcutID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("앱 열기, 키 입력, 스크립트, 붙여넣기 등을 단계로 쌓아 하나의 동작으로 만듭니다. 실행 버튼으로 테스트하고 단축키를 지정할 수 있습니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                            .foregroundColor(.secondary)
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
        // 단계 편집
        .sheet(item: $editingShortcut) { shortcut in
            ShortcutEditorView(shortcut: shortcut)
                .environmentObject(store)
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
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("동작")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("여러 단계를 하나로 묶어 실행·단축키 지정")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                    .foregroundColor(.accentColor)
                HStack(spacing: 6) {
                    Text(shortcut.name)
                        .font(.body)
                        .fontWeight(.medium)
                    Text("\(shortcut.steps.count)단계")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                            .background(Color(NSColor.separatorColor).opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            if index < min(shortcut.steps.count, 3) - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        if shortcut.steps.count > 3 {
                            Text("+\(shortcut.steps.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: 260, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("단계 없음")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                            .foregroundColor(.accentColor)
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
                    editingShortcut = shortcut
                } label: {
                    Label("단계 편집", systemImage: "list.number")
                }
                .buttonStyle(.borderless)
                .help("단계 추가·정렬·삭제")

                Spacer()

                Button {
                    store.removeShortcut(shortcut)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .help("삭제")
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func confirmCreate() {
        let name = newShortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let shortcut = store.addShortcut(name: name) {
            editingShortcut = shortcut
        }
        creatingShortcut = false
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

/// 단계 편집 시트 — 단계 추가·정렬·삭제와 동작 이름 편집
struct ShortcutEditorView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.dismiss) private var dismiss

    let shortcut: ShortcutItem

    @State private var addStepType: ActionType = .launchApp
    @State private var stepParam = ""
    @State private var stepTitle = ""
    @State private var selectedAppBundleID: String?
    @State private var selectedSystemType: SystemActionType = .lock

    // 메뉴 명령 선택 상태
    @State private var menuAppBundleID: String?
    @State private var menuAppItems: [MenuItem] = []
    @State private var isLoadingMenuItems = false
    @State private var selectedMenu: MenuItem?
    @State private var menuAppError: String?

    var steps: [ShortcutStep] {
        store.shortcuts.first(where: { $0.id == shortcut.id })?.steps ?? shortcut.steps
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(shortcut.name)
                        .font(.headline)
                    Text("\(steps.count)단계 · 총 실행 단축키: \(shortcut.combo.isEmpty ? "없음" : shortcut.combo.displayString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }

            Divider()

            // 단계 추가 영역
            Text("단계 추가")
                .font(.subheadline)
                .fontWeight(.semibold)
            addStepBar

            Divider()

            Text("단계 목록")
                .font(.subheadline)
                .fontWeight(.semibold)
            if steps.isEmpty {
                Text("아직 단계가 없습니다. 위에서 단계를 추가하세요.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            stepRow(step, index: index)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 560, height: 520, alignment: .topLeading)
    }

    // MARK: - 단계 추가

    private var addStepBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Picker("종류", selection: $addStepType) {
                    ForEach(actionStepTypes) { type in
                        Label(type.displayName, systemImage: type.systemImage).tag(type)
                    }
                }
                .labelsHidden()
                .frame(width: 160)

                switch addStepType {
                case .launchApp:
                    Picker("앱", selection: $selectedAppBundleID) {
                        Text("앱 선택").tag(String?.none)
                        ForEach(store.apps.sorted { $0.name < $1.name }) { app in
                            Text(app.name).tag(String?.some(app.bundleID))
                        }
                    }
                    .labelsHidden()
                    .frame(minWidth: 200)
                case .system:
                    Picker("시스템 동작", selection: $selectedSystemType) {
                        ForEach(SystemActionType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .labelsHidden()
                case .menuCommand, .script:
                    if addStepType == .script {
                        TextField("셸 명령 (예: open -a Safari)", text: $stepParam)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        menuCommandPicker
                    }
                case .paste:
                    TextField("붙여넣을 텍스트 (비우면 클립보드)", text: $stepParam)
                        .textFieldStyle(.roundedBorder)
                case .wait:
                    TextField("초 (예: 2.0)", text: $stepParam)
                        .textFieldStyle(.roundedBorder)
                case .coordinateClick:
                    TextField("x,y 좌표 (예: 500,400)", text: $stepParam)
                        .textFieldStyle(.roundedBorder)
                case .macro:
                    TextField("키코드 (쉼표 구분, 예: 36,36)", text: $stepParam)
                        .textFieldStyle(.roundedBorder)
                case .file:
                    TextField("파일/폴더 경로", text: $stepParam)
                        .textFieldStyle(.roundedBorder)
                case .url:
                    TextField("URL (예: https://…)", text: $stepParam)
                        .textFieldStyle(.roundedBorder)
                case .pauseUntilInput:
                    Text("⌘⇧↩를 누를 때까지 대기하는 단계입니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Button {
                addStep()
            } label: {
                Label("추가", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .onAppear {
            if selectedAppBundleID == nil {
                selectedAppBundleID = store.apps.first?.bundleID
            }
        }
    }

    private var actionStepTypes: [ActionType] {
        [.launchApp, .menuCommand, .file, .url, .script, .system, .paste, .wait, .coordinateClick, .macro, .pauseUntilInput]
    }

    private func buildStep() -> ShortcutStep? {
        switch addStepType {
        case .launchApp:
            guard let bid = selectedAppBundleID else { return nil }
            let name = store.apps.first(where: { $0.bundleID == bid })?.name ?? bid
            return ShortcutStep(type: .launchApp, target: bid, title: name)
        case .system:
            return ShortcutStep(type: .system, target: selectedSystemType.rawValue, title: selectedSystemType.displayName)
        case .menuCommand:
            guard let menu = selectedMenu else { return nil }
            var path = menu.menuPath
            if path.isEmpty { path = [menu.title] }
            return ShortcutStep(type: .menuCommand, target: menuAppBundleID ?? "", title: menu.title, menuPath: path, onlyWhenAppActive: false)
        case .script:
            guard !stepParam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return ShortcutStep(type: .script, target: stepParam, title: stepParam)
        case .paste:
            return ShortcutStep(type: .paste, target: stepParam.isEmpty ? "clipboard" : stepParam, title: stepParam.isEmpty ? "클립보드 붙여넣기" : stepParam)
        case .wait:
            let v = stepParam.isEmpty ? "1.0" : stepParam
            return ShortcutStep(type: .wait, target: v, title: "대기 \(v)초")
        case .coordinateClick:
            guard !stepParam.isEmpty else { return nil }
            return ShortcutStep(type: .coordinateClick, target: stepParam, title: "클릭 \(stepParam)")
        case .macro:
            let keys = stepParam.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard !keys.isEmpty else { return nil }
            return ShortcutStep(type: .macro, target: keys.joined(separator: ","), title: "키 입력")
        case .file:
            guard !stepParam.isEmpty else { return nil }
            return ShortcutStep(type: .file, target: stepParam, title: URL(fileURLWithPath: stepParam).lastPathComponent)
        case .url:
            guard !stepParam.isEmpty else { return nil }
            return ShortcutStep(type: .url, target: stepParam, title: stepParam)
        case .pauseUntilInput:
            return ShortcutStep(type: .pauseUntilInput, target: "", title: "입력 대기")
        }
    }

    private func addStep() {
        guard let step = buildStep() else { return }
        store.addStep(to: shortcut, step: step)
        stepParam = ""
        stepTitle = ""
        selectedMenu = nil
    }

    // MARK: - 단계 행

    private func stepRow(_ step: ShortcutStep, index: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 18)
            Image(systemName: step.type.systemImage)
                .foregroundColor(.accentColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(step.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(step.summary)
                    .font(.body)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                store.moveStep(in: shortcut, from: index, direction: .up)
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(index == 0)
            .help("위로")
            Button {
                store.moveStep(in: shortcut, from: index, direction: .down)
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(index == steps.count - 1)
            .help("아래로")
            Button {
                store.duplicateStep(in: shortcut, at: index)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("복제")
            Button {
                store.removeStep(from: shortcut, at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("삭제")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - 메뉴 명령 선택

    private var menuCommandPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Picker("앱", selection: Binding(
                    get: { menuAppBundleID },
                    set: { newValue in
                        menuAppBundleID = newValue
                        selectedMenu = nil
                        menuAppItems = []
                        loadMenuItems()
                    }
                )) {
                    Text("앱 선택").tag(String?.none)
                    ForEach(store.apps.sorted { $0.name < $1.name }) { app in
                        Text(app.name).tag(String?.some(app.bundleID))
                    }
                }
                .labelsHidden()
                .frame(minWidth: 200)
            }

            if let err = menuAppError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if isLoadingMenuItems {
                HStack { Spacer(); ProgressView().controlSize(.small); Spacer() }
            } else if !menuAppItems.isEmpty {
                Text("메뉴에서 실행할 항목을 선택하세요")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(menuAppItems) { item in
                            MenuChoiceNode(item: item, selected: selectedMenu, onSelect: { selectedMenu = $0 })
                        }
                    }
                }
                .frame(maxHeight: 160)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor)))
            }

            if let menu = selectedMenu {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(menu.menuPath.isEmpty ? menu.title : menu.menuPath.joined(separator: " > "))
                        .font(.caption)
                        .lineLimit(1)
                }
            } else {
                Text("선택한 항목 없음")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            if menuAppBundleID == nil {
                menuAppBundleID = store.apps.first?.bundleID
                loadMenuItems()
            }
        }
    }

    private func loadMenuItems() {
        guard let bid = menuAppBundleID else { return }
        menuAppError = nil
        isLoadingMenuItems = true
        menuAppItems = []
        DispatchQueue.global(qos: .userInitiated).async {
            let items = MenuEnumerator.shared.enumerateMenuItems(bundleID: bid)
            DispatchQueue.main.async {
                menuAppItems = items
                isLoadingMenuItems = false
                if items.isEmpty {
                    menuAppError = "메뉴를 열거할 수 없습니다. 앱을 실행해두고 Accessibility 권한을 확인하세요."
                }
            }
        }
    }
}

/// 동작 편집기용 재귀 메뉴 선택 노드 — 잎(실행 가능 항목)만 선택 가능
private struct MenuChoiceNode: View {
    let item: MenuItem
    let selected: MenuItem?
    let onSelect: (MenuItem) -> Void

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
                        .foregroundColor(.secondary)
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
                            .foregroundColor(.secondary)
                    }
                    if selected?.id == item.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
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

