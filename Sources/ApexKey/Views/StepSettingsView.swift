import AppKit
import SwiftUI

/// 단계 상세 설정 시트 — 흐름 제어 / AI / 변수 단계의 설정을 편집
struct StepSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더 (고정)
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: step.type.systemImage)
                        .font(.system(size: 14))
                        .foregroundColor(accentColor)
                }
                
                Text(step.type.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("ui.done".localized) { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(16)
            
            Divider()
            
            // 본문 (스크롤 — 입력 필드는 각자 내부 스크롤)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 공통: 스킵/메모
                    commonSection
                    
                    // 타입별 설정
                    typeSpecificSection
                }
                .padding(16)
            }
            .layoutPriority(1)

            Divider()

            // 하단 테스트 푸터 (항상 가시 — 스크롤 안 됨)
            StepTestFooter(step: $step)
        }
        .frame(width: 480, height: 680)
        .background(theme.secondaryBackground)
    }
    
    // MARK: - 공통 설정
    
    private var commonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ui.step_settings.general".localized)
                .font(.headline)
            
            Toggle("ui.step_settings.skip".localized, isOn: $step.isSkipped)
            
            TextField("ui.step_settings.note".localized, text: Binding(
                get: { step.note ?? "" },
                set: { step.note = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - 타입별 설정
    
    @ViewBuilder
    private var typeSpecificSection: some View {
        switch step.type {
        case .launchApp:
            LaunchAppSettingsView(step: $step)
        case .keyCombo:
            KeyPressSettingsView(step: $step)
        case .ifElse:
            IfSettingsView(step: $step)
        case .repeatLoop, .repeatEach:
            RepeatSettingsView(step: $step)
        case .chooseFromMenu:
            MenuSettingsView(step: $step)
        case .useModel:
            UseModelSettingsView(step: $step)
        case .writingTool:
            WritingToolSettingsView(step: $step)
        case .imagePlayground:
            ImagePlaygroundSettingsView(step: $step)
        case .setVariable, .outputToVariable:
            VariableStepSettingsView(step: $step)
        case .comment:
            CommentSettingsView(step: $step)
        default:
            // 기본 단계: 대상/제목 편집
            DefaultSettingsView(step: $step)
        }
    }
    
    private var accentColor: Color {
        switch step.type.category {
        case .flowControl: return .indigo
        case .ai: return .mint
        case .variables: return .cyan
        default: return .blue
        }
    }
}

// MARK: - 하단 테스트 푸터 (항상 가시 — 전 액션 공통)

/// 단계 설정 창의 하단 고정 테스트 바 (한 줄 고정).
/// 상세 결과는 별도 결과 창(StepTestResultView)으로 표시해
/// 설정 창에서 스크롤할 필요가 없도록 한다.
struct StepTestFooter: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep
    @State private var isTesting = false
    @State private var didTest = false
    @State private var testSuccess = false
    @State private var testOutput = ""
    @State private var testError = ""
    @State private var testExitCode: Int32 = 0

    var body: some View {
        HStack(spacing: 8) {
            Button {
                runTest()
            } label: {
                Label("ui.step_settings.test_run".localized, systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isTesting || !canTest(step))

            if isTesting {
                ProgressView()
                    .controlSize(.small)
                Text("ui.step_settings.running".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            } else if didTest {
                Label(
                    testSuccess ? "toast.script_test_success".localized : "toast.script_test_failed".localized,
                    systemImage: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(.caption)
                .foregroundColor(testSuccess ? theme.successColor : theme.errorColor)
                .lineLimit(1)

                Spacer()

                Button("ui.step_settings.view_result".localized) {
                    openResultWindow()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.primaryBackground)
    }

    private func canTest(_ step: ShortcutStep) -> Bool {
        switch step.type {
        case .script, .appleScript, .javaScriptForAutomation, .runScriptInShell:
            return !step.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .keyCombo:
            if let press = step.keyPress, !press.isEmpty { return true }
            return !step.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return true
        }
    }

    private func runTest() {
        let snapshot = step
        guard canTest(snapshot) else { return }
        isTesting = true
        didTest = false
        Logger.info("FEATURE", "[STEP-TEST] 테스트 실행 시작 (\(snapshot.type.rawValue))")
        DispatchQueue.global(qos: .userInitiated).async {
            let success: Bool
            let output: String
            let errorOutput: String
            let exitCode: Int32
            switch snapshot.type {
            case .appleScript:
                let r = ScriptExecutor.runAppleScript(snapshot.target)
                success = r.success; output = r.output; errorOutput = r.errorOutput; exitCode = r.success ? 0 : 1
            case .javaScriptForAutomation:
                let r = ScriptExecutor.runJXA(snapshot.target)
                success = r.success; output = r.output; errorOutput = r.errorOutput; exitCode = r.success ? 0 : 1
            case .script, .runScriptInShell:
                let result = ActionExecutor.shared.runShellScriptResult(snapshot.target)
                success = result.success; output = result.output; errorOutput = result.errorOutput; exitCode = result.exitCode
            case .keyCombo:
                let combo: HotKeyCombo?
                if let press = snapshot.keyPress, !press.isEmpty {
                    combo = press
                } else {
                    combo = ActionExecutor.parseKeyPress(from: snapshot.target)
                }
                if let combo {
                    let ok = ActionExecutor.sendKeyPress(combo)
                    success = ok; output = ok ? "" : "E-MAC-ACT-3007"; errorOutput = ""; exitCode = ok ? 0 : 1
                } else {
                    success = false; output = ""; errorOutput = "keypress.none".localized; exitCode = 1
                }
            default:
                var ctx = UseModelExecutor.ExecutionContext()
                let r = ExecutionEngine.shared.execute(steps: [snapshot], context: &ctx)
                success = r.success
                output = "\(ctx.lastOutput)"
                errorOutput = r.error ?? ""
                exitCode = r.success ? 0 : 1
            }
            DispatchQueue.main.async {
                testSuccess = success
                testOutput = output
                testError = errorOutput
                testExitCode = exitCode
                isTesting = false
                didTest = true
                openResultWindow()
            }
        }
    }

    private func openResultWindow() {
        guard didTest else { return }
        let title = step.title.isEmpty ? step.type.displayName : step.title
        (NSApp.delegate as? AppDelegate)?.showStepTestResult(
            title: title,
            success: testSuccess,
            output: testOutput,
            errorOutput: testError,
            exitCode: testExitCode
        )
    }
}

// MARK: - 테스트 결과 별도 창 (스크롤 불필요한 설정 창 + 넓은 결과 창)

/// 테스트 상세 결과를 보여주는 별도 창의 콘텐츠.
/// 설정 창(480pt)보다 넓은 560pt + 리사이즈 가능 + 내부 스크롤로
/// 긴 출력도 설정 창 스크롤 없이 확인 가능하다.
struct StepTestResultView: View {
    @Environment(\.theme) private var theme
    let stepTitle: String
    let success: Bool
    let output: String
    let errorOutput: String
    let exitCode: Int32

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(success ? theme.successColor : theme.errorColor)
                Text(stepTitle)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("ui.step_settings.exit_code".localizedFormat(Int(exitCode)))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(exitCode == 0 ? .green : .red)
                Button("ui.copy".localized) {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(fullText, forType: .string)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("ui.close".localized) {
                    NSApp.keyWindow?.performClose(nil)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Text("ui.step_settings.test_output".localized)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(theme.secondaryText)

            ScrollView {
                Text(fullText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(Color.black.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(minHeight: 280)
            .layoutPriority(1)
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 420)
        .background(theme.secondaryBackground)
    }

    private var fullText: String {
        var lines: [String] = []
        if !output.isEmpty { lines.append(output) }
        if !errorOutput.isEmpty { lines.append(errorOutput) }
        if output.isEmpty && errorOutput.isEmpty {
            lines.append("ui.step_settings.no_output".localized)
        }
        return lines.joined(separator: "\n")
    }
}

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

// MARK: - 키 조합 보내기 설정

/// 키 조합 기록기 — 참조형 홀더.
/// SwiftUI View struct를 NSEvent 모니터 escaping 클로저에서 캡처하면
/// @State/@Binding 쓰기가 stale copy에 적용되어 UI가 갱신 안 되므로,
/// 모니터 상태는 이 클래스가 소유하고 View는 @StateObject로 구독한다.
final class KeyComboRecorder: ObservableObject {
    @Published var isRecording = false
    private var monitor: Any?
    private var onCapture: ((HotKeyCombo) -> Void)?

    func start(onCapture: @escaping (HotKeyCombo) -> Void) {
        stop()
        self.onCapture = onCapture
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            // Esc면 기록 취소
            if event.keyCode == 53 {
                let stopper = self
                DispatchQueue.main.async { stopper.stop() }
                return nil
            }
            let combo = KeyboardUtil.combo(from: event)
            // 수식키 없는 단독 키는 macro 액션 영역 — 입력 삼키고 계속 대기
            guard combo.modifiers != 0, !combo.isEmpty else { return nil }
            let captured = HotKeyCombo(
                keyCode: combo.keyCode,
                modifiers: combo.modifiers,
                displayString: KeyboardUtil.displayString(keyCode: combo.keyCode, modifiers: combo.modifiers)
            )
            let handler = self.onCapture
            DispatchQueue.main.async {
                handler?(captured)
                self.stop()
            }
            return nil
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        onCapture = nil
        isRecording = false
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

struct KeyPressSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep
    @StateObject private var recorder = KeyComboRecorder()

    private var currentCombo: HotKeyCombo? {
        if let press = step.keyPress, !press.isEmpty { return press }
        let resolved = step.target.trimmingCharacters(in: .whitespacesAndNewlines)
        return resolved.isEmpty ? nil : ActionExecutor.parseKeyPress(from: resolved)
    }

    private var displayText: String {
        guard let combo = currentCombo else { return "keypress.none".localized }
        return combo.displayString.isEmpty
            ? KeyboardUtil.displayString(keyCode: combo.keyCode, modifiers: combo.modifiers)
            : combo.displayString
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(step.type.displayName)
                .font(.headline)

            HStack {
                Text(displayText)
                    .font(.system(.title3, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Spacer()
            }

            if recorder.isRecording {
                Text("keypress.recording".localized)
                    .font(.caption)
                    .foregroundColor(.orange)
            } else {
                Text("keypress.hint".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }

            HStack(spacing: 8) {
                Button(recorder.isRecording ? "keypress.stop".localized : "keypress.record".localized) {
                    if recorder.isRecording {
                        recorder.stop()
                    } else {
                        // Binding을 명시 캡처 — escaping 기록 콜백에서도 원본에 반영됨
                        let binding = $step
                        recorder.start { captured in
                            var next = binding.wrappedValue
                            next.keyPress = captured.isEmpty ? nil : captured
                            if let press = next.keyPress {
                                next.target = ActionExecutor.encodeKeyPress(press)
                            }
                            binding.wrappedValue = next
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("keypress.clear".localized) {
                    step.keyPress = nil
                    step.target = ""
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(currentCombo == nil || recorder.isRecording)
            }
        }
        .sectionCard()
        .onDisappear { recorder.stop() }
    }
}

// MARK: - If 조건 설정

struct IfSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ui.step_settings.if_condition".localized)
                .font(.headline)
            
            let condition = Binding<Condition>(
                get: { step.ifBranch?.condition ?? Condition(leftOperand: .constant(.text("")), operator: .equals, rightOperand: .constant(.text(""))) },
                set: { newValue in
                    if step.ifBranch != nil {
                        step.ifBranch?.condition = newValue
                    } else {
                        step.ifBranch = IfBranch(condition: newValue)
                    }
                }
            )
            
            ConditionEditorView(condition: condition)
            
            Divider()
            
            Text("ui.step_settings.optional_mark".localized)
                .font(.subheadline)
                .foregroundColor(theme.secondaryText)
            
            TextField("ui.label_optional".localized, text: Binding(
                get: { step.ifBranch?.label ?? "" },
                set: { step.ifBranch?.label = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
            Text("ui.step_settings.otherwise_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        }
        .sectionCard()
    }
}

// MARK: - 조건 편집기

struct ConditionEditorView: View {
    @Environment(\.theme) private var theme
    @Binding var condition: Condition
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 연산자 선택
            Picker("ui.step_settings.operator".localized, selection: operatorBinding) {
                ForEach(ConditionOperator.allCases) { op in
                    Text(op.displayName).tag(op)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 200)
            
            // 왼쪽 값
            Text("ui.step_settings.left_value".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            operandEditor($condition.leftOperand)
            
            // 오른쪽 값
            if condition.operator.requiresRightOperand {
                Text("ui.step_settings.right_value".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                operandEditor(Binding(
                    get: { condition.rightOperand ?? .constant(.text("")) },
                    set: { condition.rightOperand = $0 }
                ))
            }
        }
    }
    
    private var operatorBinding: Binding<ConditionOperator> {
        Binding(
            get: { condition.operator },
            set: { condition.operator = $0 }
        )
    }
    
    @ViewBuilder
    private func operandEditor(_ operand: Binding<ConditionOperand>) -> some View {
        // 변수 선택(간단화: 상수 텍스트만 편집)
        TextField("ui.condition.value".localized, text: Binding(
            get: {
                if case .constant(let v) = operand.wrappedValue, case .text(let s) = v {
                    return s
                }
                return ""
            },
            set: {
                operand.wrappedValue = .constant(.text($0))
            }
        ))
        .textFieldStyle(.roundedBorder)
    }
}

// MARK: - 반복 설정

struct RepeatSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep
    
    private var isForEach: Bool { step.type == .repeatEach }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isForEach ? "ui.step_settings.repeat_each".localized : "ui.step_settings.repeat_count".localized)
                .font(.headline)
            
            if isForEach {
                TextField("ui.step_settings.collection_uuid".localized, text: Binding(
                    get: { step.repeatLoop?.collectionVariable?.uuidString ?? "" },
                    set: { step.repeatLoop?.collectionVariable = UUID(uuidString: $0) }
                ))
                .textFieldStyle(.roundedBorder)
                
                Text("ui.step_settings.collection_hint".localized)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            } else {
                Stepper(value: Binding(
                    get: { Double(step.repeatLoop?.count ?? 1) },
                    set: { step.repeatLoop?.count = Int($0) }
                ), in: 1...100) {
                    Text("ui.step_settings.repeat_count_value".localizedFormat(step.repeatLoop?.count ?? 1))
                }
            }
            
            Divider()
            
            TextField("ui.label_optional".localized, text: Binding(
                get: { step.repeatLoop?.label ?? "" },
                set: { step.repeatLoop?.label = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
        }
        .sectionCard()
    }
}

// MARK: - 메뉴 선택 설정

struct MenuSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep
    
    @State private var newOptionTitle = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ui.step_settings.menu_select".localized)
                .font(.headline)
            
            TextField("ui.prompt".localized, text: Binding(
                get: { step.chooseFromMenu?.prompt ?? "" },
                set: { step.chooseFromMenu?.prompt = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
            Divider()
            
            Text("ui.options".localized)
                .font(.subheadline)
                .foregroundColor(theme.secondaryText)
            
            ForEach(step.chooseFromMenu?.options ?? []) { option in
                HStack {
                    Text(option.title)
                        .font(.body)
                    Spacer()
                    Button(role: .destructive) {
                        step.chooseFromMenu?.options.removeAll { $0.id == option.id }
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 4)
            }
            
            HStack {
                TextField("ui.step_settings.new_option".localized, text: $newOptionTitle)
                    .textFieldStyle(.roundedBorder)
                Button("ui.add".localized) {
                    guard !newOptionTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    if step.chooseFromMenu != nil {
                        step.chooseFromMenu?.options.append(MenuOption(title: newOptionTitle))
                    } else {
                        step.chooseFromMenu = ChooseFromMenu(
                            prompt: "ui.select_option".localized,
                            options: [MenuOption(title: newOptionTitle)],
                            allowMultipleSelection: false,
                            showCancelButton: true,
                            outputVariable: UUID()
                        )
                    }
                    newOptionTitle = ""
                }
                .buttonStyle(.bordered)
            }
            
            Toggle("ui.step_settings.allow_multiple".localized, isOn: Binding(
                get: { step.chooseFromMenu?.allowMultipleSelection ?? false },
                set: { step.chooseFromMenu?.allowMultipleSelection = $0 }
            ))
            
            Toggle("ui.step_settings.show_cancel".localized, isOn: Binding(
                get: { step.chooseFromMenu?.showCancelButton ?? true },
                set: { step.chooseFromMenu?.showCancelButton = $0 }
            ))
        }
        .sectionCard()
    }
}

// MARK: - Use Model 설정

struct UseModelSettingsView: View {
    @Binding var step: ShortcutStep
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("action.useModel"))
                .font(.headline)
            
            Picker("ui.model".localized, selection: Binding(
                get: { step.useModel?.modelType ?? .onDevice },
                set: { step.useModel?.modelType = $0 }
            )) {
                ForEach(AIModelType.allCases) { model in
                    Text(model.displayName).tag(model)
                }
            }
            .pickerStyle(.segmented)
            
            TextField("ui.prompt".localized, text: Binding(
                get: { step.useModel?.prompt ?? "" },
                set: { step.useModel?.prompt = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
            Picker("ui.output_type".localized, selection: Binding(
                get: { step.useModel?.outputType ?? .text },
                set: { step.useModel?.outputType = $0 }
            )) {
                ForEach(AIOutputType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            Toggle("ui.step_settings.follow_up_chat".localized, isOn: Binding(
                get: { step.useModel?.followUp ?? false },
                set: { step.useModel?.followUp = $0 }
            ))
        }
        .sectionCard()
    }
}

// MARK: - Writing Tool 설정

struct WritingToolSettingsView: View {
    @Binding var step: ShortcutStep
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("action.writingTool"))
                .font(.headline)
            
            Picker("ui.shortcut".localized, selection: Binding(
                get: { step.writingTool?.action ?? .proofread },
                set: { step.writingTool?.action = $0 }
            )) {
                ForEach(WritingToolAction.allCases) { action in
                    Text(action.displayName).tag(action)
                }
            }
            .pickerStyle(.menu)
            
            if step.writingTool?.action == .changeTone {
                Picker("ui.tone".localized, selection: Binding(
                    get: { step.writingTool?.tone ?? .professional },
                    set: { step.writingTool?.tone = $0 }
                )) {
                    ForEach(WritingTone.allCases) { tone in
                        Text(tone.displayName).tag(tone)
                    }
                }
                .pickerStyle(.menu)
            }
            
            TextField("ui.step_settings.input_uuid".localized, text: Binding(
                get: { step.writingTool?.inputVariable.uuidString ?? "" },
                set: { step.writingTool?.inputVariable = UUID(uuidString: $0) ?? UUID() }
            ))
            .textFieldStyle(.roundedBorder)
        }
        .sectionCard()
    }
}

// MARK: - Image Playground 설정

struct ImagePlaygroundSettingsView: View {
    @Binding var step: ShortcutStep
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ui.editor.step_image".localized)
                .font(.headline)
            
            TextField("ui.prompt".localized, text: Binding(
                get: { step.imagePlayground?.prompt ?? "" },
                set: { step.imagePlayground?.prompt = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
            Picker("ui.style".localized, selection: Binding(
                get: { step.imagePlayground?.style ?? .animation },
                set: { step.imagePlayground?.style = $0 }
            )) {
                ForEach(ImagePlaygroundStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.segmented)
        }
        .sectionCard()
    }
}

// MARK: - 변수 단계 설정

struct VariableStepSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("action.setVariable"))
                .font(.headline)
            
            TextField("ui.step_settings.variable_value".localized, text: $step.target)
                .textFieldStyle(.roundedBorder)
            
            Text("ui.step_settings.variable_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        }
        .sectionCard()
    }
}

// MARK: - 코멘트 설정

struct CommentSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("action.comment"))
                .font(.headline)
            
            TextEditor(text: Binding(
                get: { step.note ?? "" },
                set: { step.note = $0 }
            ))
            .frame(height: 120)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(theme.secondaryText.opacity(0.3))
            )
        }
        .sectionCard()
    }
}

// MARK: - 기본 설정

struct DefaultSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep

    private var isScript: Bool {
        step.type == .script || step.type == .appleScript
            || step.type == .javaScriptForAutomation || step.type == .runScriptInShell
    }

    private var scriptPromptKey: String {
        switch step.type {
        case .appleScript: return "ui.app_detail.applescript_prompt"
        case .javaScriptForAutomation: return "ui.app_detail.jxa_prompt"
        default: return "ui.app_detail.shell_prompt"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(step.type.displayName)
                .font(.headline)

            Text("ui.title".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("ui.title".localized, text: $step.title)
                .textFieldStyle(.roundedBorder)

            if isScript {
                Text(scriptPromptKey.localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                // 고정 높이 + 내부 스크롤 (창 전체 스크롤 아님).
                // TextEditor 자체가 내부 스크롤을 제공하므로 높이를 고정한다.
                TextEditor(text: $step.target)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 180)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(theme.secondaryText.opacity(0.3))
                    )
                    .scrollContentBackground(.hidden)
                // 테스트 실행은 하단 고정 푸터(StepTestFooter)에서 수행
            } else {
                Text("ui.step_settings.target_value".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                TextField("ui.step_settings.target_value".localized, text: $step.target)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .sectionCard()
    }
}

// MARK: - 확장

private struct SectionCardModifier: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private extension View {
    func sectionCard() -> some View {
        modifier(SectionCardModifier())
    }
}
