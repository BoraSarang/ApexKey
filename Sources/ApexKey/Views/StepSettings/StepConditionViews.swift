import AppKit
import SwiftUI

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
