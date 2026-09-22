import SwiftUI
import AppKit

/// iOS Shortcuts 스타일 단축어 편집기 — 3컬럼 레이아웃
struct ShortcutEditorView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme
    
    let shortcut: ShortcutItem
    
    @State private var steps: [ShortcutStep] = []
    @State private var selectedStepID: UUID?
    @State private var isEditingMode = true
    @State private var selectedActionType: ActionType?
    @State private var showingActionDetail = false
    @State private var searchText = ""
    @State private var shortcutName: String
    @State private var shortcutDescription: String
    @State private var isShowingAutomationSettings = false
    @State private var shortcutAutomations: [AutomationTrigger]
    @State private var shortcutVariables: [Variable]
    
    init(shortcut: ShortcutItem, initialSelectedStepID: UUID? = nil) {
        self.shortcut = shortcut
        _steps = State(initialValue: shortcut.steps)
        _selectedStepID = State(initialValue: initialSelectedStepID)
        _shortcutName = State(initialValue: shortcut.name)
        _shortcutDescription = State(initialValue: shortcut.description)
        _shortcutAutomations = State(initialValue: shortcut.automations)
        _shortcutVariables = State(initialValue: shortcut.variables)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 왼쪽: 액션 카탈로그
            ActionCatalogView(selectedActionType: $selectedActionType)
                .background(theme.primaryBackground)
            
            Divider()
            
            // 가운데: 단계 목록
            centerPanel
            
            Divider()
            
            // 오른쪽: 변수 패널
            VariablePanelView(selectedVariables: Binding(
                get: { shortcutVariables },
                set: { shortcutVariables = $0; saveVariables() }
            ))
            .background(theme.primaryBackground)
        }
        .frame(minWidth: 900, minHeight: 600)
        .onChange(of: selectedActionType) { newType in
            if let type = newType {
                addStepOfType(type)
                selectedActionType = nil
            }
        }
        .onChange(of: steps) { _ in
            // 독립 단계 설정 창에서 Binding으로 수정된 내용 자동 저장
            saveSteps()
        }
        .onDisappear {
            // 빨간X·Cmd+W로 닫아도 이름/설명/단계 저장 (saveAndClose를 거치지 않는 경로)
            saveName()
            saveDescription()
            saveSteps()
        }
        .sheet(isPresented: $showingActionDetail) {
            if let type = selectedActionType {
                ActionDetailView(
                    actionType: type,
                    target: Binding(
                        get: { steps.last?.target ?? "" },
                        set: { newValue in
                            if let lastIndex = steps.indices.last {
                                steps[lastIndex].target = newValue
                            }
                        }
                    ),
                    title: Binding(
                        get: { steps.last?.title ?? "" },
                        set: { newValue in
                            if let lastIndex = steps.indices.last {
                                steps[lastIndex].title = newValue
                            }
                        }
                    )
                )
            }
        }
        .sheet(isPresented: $isShowingAutomationSettings) {
            AutomationSettingsView(automations: $shortcutAutomations)
                .onDisappear { saveAutomations() }
        }
    }
    
    // MARK: - 가운데 패널
    
    private var centerPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더
            header
            
            Divider()
            
            // 단계 목록
            StepListView(
                steps: steps,
                isEditing: isEditingMode,
                selectedStepID: $selectedStepID,
                onMove: moveSteps,
                onDelete: deleteSteps,
                onDuplicate: duplicateStep,
                onToggleSkip: toggleSkipStep,
                onSelect: selectStep
            )
            
            Divider()
            
            // 하단 컨트롤 바
            bottomBar
        }
        .background(theme.primaryBackground)
        .frame(minWidth: 390)
    }
    
    // MARK: - 헤더
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // 단축어 아이콘 + 색상
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(shortcutColor)
                        .frame(width: 44, height: 44)
                    Image(systemName: shortcutIconName)
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    // 이름 편집
                    TextField("ui.name".localized, text: $shortcutName)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .onSubmit { saveName() }
                    
                    // 설명
                    Text(shortcutDescription.isEmpty ? "ui.editor.steps_count".localizedFormat(steps.count) : shortcutDescription)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
                
                Spacer()
                
                // 실행 버튼
                Button {
                    executeShortcut()
                } label: {
                    Label("ui.run".localized, systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(steps.isEmpty)
                
                // 자동화 설정
                Button {
                    isShowingAutomationSettings = true
                } label: {
                    Label("category.automation".localized, systemImage: shortcutAutomations.isEmpty ? "bolt.badge.clock" : "bolt.fill")
                }
                .buttonStyle(.bordered)
                .help("ui.editor.automation_help".localized)
                
                // 단축키 지정
                Button {
                    // 단축키 지정 시트
                } label: {
                    if shortcut.combo.isEmpty {
                        Label("ui.hotkey".localized, systemImage: "keyboard")
                    } else {
                        Text(shortcut.combo.displayString)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                .buttonStyle(.bordered)
                
                // 닫기
                Button {
                    saveAndClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(.borderless)
            }
            
            // 편집 모드 토글
            HStack(spacing: 12) {
                Toggle("ui.editor.edit_mode".localized, isOn: $isEditingMode)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                
                if isEditingMode {
                    Text("ui.editor.drag_hint".localized)
                        .font(.caption2)
                        .foregroundColor(theme.secondaryText)
                }
                
                Spacer()
                
                // 단계 수 표시
                Text("ui.editor.steps_count".localizedFormat(steps.count))
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - 하단 바
    
    private var bottomBar: some View {
        HStack(spacing: 12) {
            // 이름 변경
            HStack(spacing: 6) {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                TextField("ui.rename".localized, text: $shortcutName)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .frame(width: 120)
                    .onSubmit { saveName() }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // 설명 변경
            HStack(spacing: 6) {
                Image(systemName: "text.alignleft")
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                TextField("ui.description".localized, text: $shortcutDescription)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .frame(width: 200)
                    .onSubmit { saveDescription() }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            Spacer()
            
            // 단계 관리 버튼들
            if isEditingMode && !steps.isEmpty {
                Menu {
                    Button("ui.editor.select_all".localized) {
                        // 전체 선택 로직
                    }
                    Divider()
                    Button("ui.editor.toggle_all_skips".localized) {
                        toggleAllSkips()
                    }
                    Button("ui.editor.delete_all".localized) {
                        deleteAllSteps()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.caption)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.primaryBackground)
    }
    
    // MARK: - 단계 선택 (설정 시트)
    
    private var selectedStepIndex: Int? {
        guard let id = selectedStepID else { return nil }
        return steps.firstIndex(where: { $0.id == id })
    }
    
    private func stepBinding(for step: ShortcutStep) -> Binding<ShortcutStep> {
        guard let index = steps.firstIndex(where: { $0.id == step.id }) else {
            return Binding.constant(step)
        }
        return Binding(
            get: { steps[index] },
            set: { steps[index] = $0 }
        )
    }
    
    func selectStep(_ step: ShortcutStep) {
        selectedStepID = step.id
        // 모든 단계 타입에서 설정 창 표시 — 스크립트 명령(target) 등 확인/편집용
        openStepSettings(for: step)
    }

    /// 단계 상세 설정을 독립 창으로 표시 — steps 배열 요소를 가리키는 Binding 전달
    private func openStepSettings(for step: ShortcutStep) {
        (NSApp.delegate as? AppDelegate)?.showStepSettings(for: stepBinding(for: step))
    }
    
    // MARK: - 액션 추가
    
    private func addStepOfType(_ type: ActionType) {
        let newStep = createDefaultStep(for: type)
        steps.append(newStep)
        saveSteps()
    }
    
    private func createDefaultStep(for type: ActionType) -> ShortcutStep {
        switch type {
        case .launchApp:
            var step = ShortcutStep(type: .launchApp, target: "", title: "ui.editor.step_launch_app".localized)
            step.launchConfig = LaunchConfig(mode: .toggle)
            return step
        case .keyCombo:
            return ShortcutStep(type: .keyCombo, target: "", title: "ui.editor.step_keypress".localized)
        case .system:
            return ShortcutStep(type: .system, target: "lock", title: "ui.editor.step_lock".localized)
        case .script:
            return ShortcutStep(type: .script, target: "", title: "ui.editor.step_script".localized)
        case .appleScript:
            return ShortcutStep(type: .appleScript, target: "tell application \"Finder\" to get name", title: "ui.editor.step_applescript".localized)
        case .javaScriptForAutomation:
            return ShortcutStep(type: .javaScriptForAutomation, target: "Application('Finder').name()", title: "ui.editor.step_jxa".localized)
        case .runScriptInShell:
            return ShortcutStep(type: .runScriptInShell, target: "", title: "ui.editor.step_shell".localized)
        case .url:
            return ShortcutStep(type: .url, target: "", title: "URL")
        case .file:
            return ShortcutStep(type: .file, target: "", title: "ui.editor.step_file".localized)
        case .paste:
            return ShortcutStep(type: .paste, target: "clipboard", title: "ui.editor.step_clipboard".localized)
        case .wait:
            return ShortcutStep(type: .wait, target: "1.0", title: "ui.editor.step_wait".localized)
        case .coordinateClick:
            return ShortcutStep(type: .coordinateClick, target: "0,0", title: "ui.editor.step_click".localized)
        case .macro:
            return ShortcutStep(type: .macro, target: "", title: "ui.editor.step_type".localized)
        case .pauseUntilInput:
            return ShortcutStep(type: .pauseUntilInput, target: "", title: "ui.editor.step_pause".localized)
        case .menuCommand:
            return ShortcutStep(type: .menuCommand, target: "", title: "ui.editor.step_menu".localized)
        case .ifElse:
            var step = ShortcutStep(type: .ifElse, target: "", title: "If")
            step.ifBranch = IfBranch(condition: Condition(
                leftOperand: .constant(.text("")),
                operator: .equals,
                rightOperand: .constant(.text(""))
            ))
            return step
        case .repeatLoop:
            var step = ShortcutStep(type: .repeatLoop, target: "", title: "ui.editor.step_repeat".localized)
            step.repeatLoop = RepeatLoop(mode: .count, count: 3, steps: [])
            return step
        case .repeatEach:
            var step = ShortcutStep(type: .repeatEach, target: "", title: "ui.editor.step_repeat_each".localized)
            step.repeatLoop = RepeatLoop(mode: .forEach, steps: [])
            return step
        case .chooseFromMenu:
            var step = ShortcutStep(type: .chooseFromMenu, target: "", title: "ui.editor.step_choose_menu".localized)
            step.chooseFromMenu = ChooseFromMenu(
                prompt: "ui.select_option".localized,
                options: [MenuOption(title: "ui.editor.option_default".localized)],
                allowMultipleSelection: false,
                showCancelButton: true,
                outputVariable: UUID()
            )
            return step
        case .useModel:
            var step = ShortcutStep(type: .useModel, target: "", title: "ui.editor.step_use_model".localized)
            step.useModel = UseModelStep(prompt: "", outputVariable: UUID())
            return step
        case .writingTool:
            var step = ShortcutStep(type: .writingTool, target: "", title: "ui.editor.step_writing_tool".localized)
            step.writingTool = WritingToolStep(action: .proofread, inputVariable: UUID(), outputVariable: UUID())
            return step
        case .imagePlayground:
            var step = ShortcutStep(type: .imagePlayground, target: "", title: "ui.editor.step_image".localized)
            step.imagePlayground = ImagePlaygroundStep(prompt: "", outputVariable: UUID())
            return step
        case .setVariable:
            var step = ShortcutStep(type: .setVariable, target: "", title: "ui.editor.step_set_var".localized)
            step.outputVariables = [Variable(name: "ui.editor.new_variable".localized, type: .manual, valueType: .text)]
            return step
        case .outputToVariable:
            var step = ShortcutStep(type: .outputToVariable, target: "", title: "ui.editor.step_output_var".localized)
            step.outputVariables = [Variable(name: "ui.output".localized, type: .magic, valueType: .any)]
            return step
        case .comment:
            var step = ShortcutStep(type: .comment, target: "", title: "ui.editor.step_comment".localized)
            step.note = ""
            return step
        case .stopShortcut:
            var step = ShortcutStep(type: .stopShortcut, target: "", title: "action.stopShortcut".localized)
            // 출력 변수 선택 가능하도록 actionParameters에 인코딩 (E-MAC-UX-9003)
            let action = StopShortcutAction(outputVariable: nil)
            step.actionParameters = try? JSONEncoder().encode(action)
            step.outputVariables = nil
            return step
        default:
            return ShortcutStep(type: type, target: "", title: type.displayName)
        }
    }
    
    // MARK: - 단계 관리
    
    private func moveSteps(from source: IndexSet, to destination: Int) {
        steps.move(fromOffsets: source, toOffset: destination)
        saveSteps()
    }
    
    private func deleteSteps(at offsets: IndexSet) {
        steps.remove(atOffsets: offsets)
        saveSteps()
    }
    
    private func duplicateStep(at index: Int) {
        guard index < steps.count else { return }
        var duplicate = steps[index]
        duplicate.id = UUID()
        steps.insert(duplicate, at: index + 1)
        saveSteps()
    }
    
    private func toggleSkipStep(at index: Int) {
        guard index < steps.count else { return }
        steps[index].isSkipped.toggle()
        saveSteps()
    }
    
    private func toggleAllSkips() {
        let allSkipped = steps.allSatisfy { $0.isSkipped }
        for i in steps.indices {
            steps[i].isSkipped = !allSkipped
        }
        saveSteps()
    }
    
    private func deleteAllSteps() {
        steps.removeAll()
        saveSteps()
    }
    
    // MARK: - 저장
    
    private func saveSteps() {
        store.updateShortcutSteps(shortcut, steps: steps)
    }
    
    private func saveName() {
        let name = shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        store.updateShortcutName(shortcut, name: name)
    }
    
    private func saveDescription() {
        store.updateShortcutDescription(shortcut, description: shortcutDescription)
    }
    
    private func saveAutomations() {
        store.updateShortcutAutomations(shortcut, automations: shortcutAutomations)
    }
    
    private func saveVariables() {
        store.updateShortcutVariables(shortcut, variables: shortcutVariables)
    }
    
    private func saveAndClose() {
        saveName()
        saveDescription()
        saveSteps()
        // 편집기는 이제 독립 창이므로 표준 닫기 동작으로 창을 닫는다
        NSApp.keyWindow?.performClose(nil)
    }
    
    private func executeShortcut() {
        let shortcutToRun = ShortcutItem(
            id: shortcut.id,
            name: shortcutName.isEmpty ? shortcut.name : shortcutName,
            steps: steps,
            combo: shortcut.combo,
            icon: shortcut.icon,
            color: shortcut.color,
            aiModel: shortcut.aiModel,
            description: shortcutDescription,
            automations: shortcutAutomations,
            variables: shortcutVariables,
            permissions: shortcut.permissions
        )
        DispatchQueue.global(qos: .userInitiated).async {
            ActionExecutor.shared.execute(shortcutToRun)
        }
    }
    
    // MARK: - 헬퍼
    
    private var shortcutColor: Color {
        switch shortcut.color {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .mint: return .mint
        case .teal: return .teal
        case .cyan: return .cyan
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .brown: return .brown
        case .gray: return .gray
        }
    }
    
    private var shortcutIconName: String {
        switch shortcut.icon {
        case .sfSymbol(let name): return name
        case .emoji: return "bolt.fill"
        }
    }
}
