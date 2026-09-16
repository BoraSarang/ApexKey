import SwiftUI

/// 단계 상세 설정 시트 — 흐름 제어 / AI / 변수 단계의 설정을 편집
struct StepSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더
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
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 공통: 스킵/메모
                    commonSection
                    
                    // 타입별 설정
                    typeSpecificSection
                }
                .padding(16)
            }
        }
        .frame(width: 480, height: 560)
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
    @Binding var step: ShortcutStep
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("settings.title"))
                .font(.headline)
            
            TextField("ui.title".localized, text: $step.title)
                .textFieldStyle(.roundedBorder)
            
            TextField("ui.step_settings.target_value".localized, text: $step.target)
                .textFieldStyle(.roundedBorder)
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
