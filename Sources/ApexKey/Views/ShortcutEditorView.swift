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
    
    init(shortcut: ShortcutItem) {
        self.shortcut = shortcut
        _steps = State(initialValue: shortcut.steps)
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
                    TextField("이름", text: $shortcutName)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .onSubmit { saveName() }
                    
                    // 설명
                    Text(shortcutDescription.isEmpty ? "\(steps.count)단계" : shortcutDescription)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
                
                Spacer()
                
                // 실행 버튼
                Button {
                    executeShortcut()
                } label: {
                    Label("실행", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(steps.isEmpty)
                
                // 자동화 설정
                Button {
                    isShowingAutomationSettings = true
                } label: {
                    Label("자동화", systemImage: shortcutAutomations.isEmpty ? "bolt.badge.clock" : "bolt.fill")
                }
                .buttonStyle(.bordered)
                .help("개인 자동화 트리거 설정")
                
                // 단축키 지정
                Button {
                    // 단축키 지정 시트
                } label: {
                    if shortcut.combo.isEmpty {
                        Label("단축키", systemImage: "keyboard")
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
                Toggle("편집 모드", isOn: $isEditingMode)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                
                if isEditingMode {
                    Text("단계를 드래그하여 순서를 변경할 수 있습니다")
                        .font(.caption2)
                        .foregroundColor(theme.secondaryText)
                }
                
                Spacer()
                
                // 단계 수 표시
                Text("\(steps.count)단계")
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
                TextField("이름 변경", text: $shortcutName)
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
                TextField("설명", text: $shortcutDescription)
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
                    Button("전체 선택") {
                        // 전체 선택 로직
                    }
                    Divider()
                    Button("스킵 모두 토글") {
                        toggleAllSkips()
                    }
                    Button("전체 삭제") {
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
        // 설정이 있는 단계 타입만 독립 설정 창 표시
        switch step.type {
        case .ifElse, .repeatLoop, .repeatEach, .chooseFromMenu,
             .useModel, .writingTool, .imagePlayground,
             .setVariable, .outputToVariable, .comment:
            openStepSettings(for: step)
        default:
            break
        }
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
            return ShortcutStep(type: .launchApp, target: "", title: "앱 선택")
        case .system:
            return ShortcutStep(type: .system, target: "lock", title: "잠금")
        case .script:
            return ShortcutStep(type: .script, target: "", title: "스크립트")
        case .url:
            return ShortcutStep(type: .url, target: "", title: "URL")
        case .file:
            return ShortcutStep(type: .file, target: "", title: "파일")
        case .paste:
            return ShortcutStep(type: .paste, target: "clipboard", title: "클립보드")
        case .wait:
            return ShortcutStep(type: .wait, target: "1.0", title: "대기 1초")
        case .coordinateClick:
            return ShortcutStep(type: .coordinateClick, target: "0,0", title: "클릭")
        case .macro:
            return ShortcutStep(type: .macro, target: "", title: "키 입력")
        case .pauseUntilInput:
            return ShortcutStep(type: .pauseUntilInput, target: "", title: "입력 대기")
        case .menuCommand:
            return ShortcutStep(type: .menuCommand, target: "", title: "메뉴 명령")
        case .ifElse:
            var step = ShortcutStep(type: .ifElse, target: "", title: "If")
            step.ifBranch = IfBranch(condition: Condition(
                leftOperand: .constant(.text("")),
                operator: .equals,
                rightOperand: .constant(.text(""))
            ))
            return step
        case .repeatLoop:
            var step = ShortcutStep(type: .repeatLoop, target: "", title: "반복")
            step.repeatLoop = RepeatLoop(mode: .count, count: 3, steps: [])
            return step
        case .repeatEach:
            var step = ShortcutStep(type: .repeatEach, target: "", title: "각 항목 반복")
            step.repeatLoop = RepeatLoop(mode: .forEach, steps: [])
            return step
        case .chooseFromMenu:
            var step = ShortcutStep(type: .chooseFromMenu, target: "", title: "메뉴에서 선택")
            step.chooseFromMenu = ChooseFromMenu(
                prompt: "옵션을 선택하세요",
                options: [MenuOption(title: "옵션 1")],
                allowMultipleSelection: false,
                showCancelButton: true,
                outputVariable: UUID()
            )
            return step
        case .useModel:
            var step = ShortcutStep(type: .useModel, target: "", title: "모델 사용")
            step.useModel = UseModelStep(prompt: "", outputVariable: UUID())
            return step
        case .writingTool:
            var step = ShortcutStep(type: .writingTool, target: "", title: "라이팅 툴")
            step.writingTool = WritingToolStep(action: .proofread, inputVariable: UUID(), outputVariable: UUID())
            return step
        case .imagePlayground:
            var step = ShortcutStep(type: .imagePlayground, target: "", title: "이미지 생성")
            step.imagePlayground = ImagePlaygroundStep(prompt: "", outputVariable: UUID())
            return step
        case .setVariable:
            var step = ShortcutStep(type: .setVariable, target: "", title: "변수 설정")
            step.outputVariables = [Variable(name: "새 변수", type: .manual, valueType: .text)]
            return step
        case .outputToVariable:
            var step = ShortcutStep(type: .outputToVariable, target: "", title: "출력을 변수로")
            step.outputVariables = [Variable(name: "출력", type: .magic, valueType: .any)]
            return step
        case .comment:
            var step = ShortcutStep(type: .comment, target: "", title: "코멘트")
            step.note = ""
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
        let duplicate = steps[index]
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
            name: shortcut.name,
            steps: steps,
            combo: shortcut.combo
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

// MARK: - ConfigStore 확장 (편집기용)

extension ConfigStore {
    func updateShortcutSteps(_ shortcut: ShortcutItem, steps: [ShortcutStep]) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index].steps = steps
            shortcuts[index].modifiedAt = Date()
            syncShortcut(shortcuts[index])
        }
    }
    
    func updateShortcutName(_ shortcut: ShortcutItem, name: String) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index].name = name
            shortcuts[index].modifiedAt = Date()
            syncShortcut(shortcuts[index])
        }
    }
    
    func updateShortcutDescription(_ shortcut: ShortcutItem, description: String) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index].description = description
            shortcuts[index].modifiedAt = Date()
            syncShortcut(shortcuts[index])
        }
    }
    
    func updateShortcutAutomations(_ shortcut: ShortcutItem, automations: [AutomationTrigger]) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index].automations = automations
            shortcuts[index].modifiedAt = Date()
            syncShortcut(shortcuts[index])
            // 해당 단축어 자동화 재등록
            AutomationManager.shared.unregister(shortcutID: shortcut.id)
            AutomationManager.shared.register(shortcut: shortcuts[index])
        }
    }
    
    func updateShortcutVariables(_ shortcut: ShortcutItem, variables: [Variable]) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index].variables = variables
            shortcuts[index].modifiedAt = Date()
            syncShortcut(shortcuts[index])
        }
    }
}
