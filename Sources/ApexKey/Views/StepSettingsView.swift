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
                
                Button("완료") { dismiss() }
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
            Text("일반")
                .font(.headline)
            
            Toggle("이 단계 스킵", isOn: $step.isSkipped)
            
            TextField("메모 (선택)", text: Binding(
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
            Text("If 조건")
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
            
            Text("선택 사항")
                .font(.subheadline)
                .foregroundColor(theme.secondaryText)
            
            TextField("라벨 (선택)", text: Binding(
                get: { step.ifBranch?.label ?? "" },
                set: { step.ifBranch?.label = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
            Text("그 외(Otherwise) 분기는 단계를 If 아래에 삽입해 관리합니다.")
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
            Picker("연산자", selection: operatorBinding) {
                ForEach(ConditionOperator.allCases) { op in
                    Text(op.displayName).tag(op)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 200)
            
            // 왼쪽 값
            Text("왼쪽 값")
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            operandEditor($condition.leftOperand)
            
            // 오른쪽 값
            if condition.operator.requiresRightOperand {
                Text("오른쪽 값")
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
        TextField("값", text: Binding(
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
            Text(isForEach ? "반복 (각 항목)" : "반복 (횟수)")
                .font(.headline)
            
            if isForEach {
                TextField("컬렉션 변수 (UUID)", text: Binding(
                    get: { step.repeatLoop?.collectionVariable?.uuidString ?? "" },
                    set: { step.repeatLoop?.collectionVariable = UUID(uuidString: $0) }
                ))
                .textFieldStyle(.roundedBorder)
                
                Text("컬렉션(리스트)을 소유한 변수의 ID를 입력합니다.")
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            } else {
                Stepper(value: Binding(
                    get: { Double(step.repeatLoop?.count ?? 1) },
                    set: { step.repeatLoop?.count = Int($0) }
                ), in: 1...100) {
                    Text("반복 횟수: \(step.repeatLoop?.count ?? 1)")
                }
            }
            
            Divider()
            
            TextField("라벨 (선택)", text: Binding(
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
            Text("메뉴 선택")
                .font(.headline)
            
            TextField("프롬프트", text: Binding(
                get: { step.chooseFromMenu?.prompt ?? "" },
                set: { step.chooseFromMenu?.prompt = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
            Divider()
            
            Text("옵션")
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
                TextField("새 옵션", text: $newOptionTitle)
                    .textFieldStyle(.roundedBorder)
                Button("추가") {
                    guard !newOptionTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    if step.chooseFromMenu != nil {
                        step.chooseFromMenu?.options.append(MenuOption(title: newOptionTitle))
                    } else {
                        step.chooseFromMenu = ChooseFromMenu(
                            prompt: "옵션을 선택하세요",
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
            
            Toggle("여러 개 선택 허용", isOn: Binding(
                get: { step.chooseFromMenu?.allowMultipleSelection ?? false },
                set: { step.chooseFromMenu?.allowMultipleSelection = $0 }
            ))
            
            Toggle("취소 버튼 표시", isOn: Binding(
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
            Text("모델 사용")
                .font(.headline)
            
            Picker("모델", selection: Binding(
                get: { step.useModel?.modelType ?? .onDevice },
                set: { step.useModel?.modelType = $0 }
            )) {
                ForEach(AIModelType.allCases) { model in
                    Text(model.displayName).tag(model)
                }
            }
            .pickerStyle(.segmented)
            
            TextField("프롬프트", text: Binding(
                get: { step.useModel?.prompt ?? "" },
                set: { step.useModel?.prompt = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
            Picker("출력 타입", selection: Binding(
                get: { step.useModel?.outputType ?? .text },
                set: { step.useModel?.outputType = $0 }
            )) {
                ForEach(AIOutputType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            Toggle("Follow Up (채팅)", isOn: Binding(
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
            Text("라이팅 툴")
                .font(.headline)
            
            Picker("동작", selection: Binding(
                get: { step.writingTool?.action ?? .proofread },
                set: { step.writingTool?.action = $0 }
            )) {
                ForEach(WritingToolAction.allCases) { action in
                    Text(action.displayName).tag(action)
                }
            }
            .pickerStyle(.menu)
            
            if step.writingTool?.action == .changeTone {
                Picker("톤", selection: Binding(
                    get: { step.writingTool?.tone ?? .professional },
                    set: { step.writingTool?.tone = $0 }
                )) {
                    ForEach(WritingTone.allCases) { tone in
                        Text(tone.displayName).tag(tone)
                    }
                }
                .pickerStyle(.menu)
            }
            
            TextField("입력 변수 (UUID)", text: Binding(
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
            Text("이미지 생성")
                .font(.headline)
            
            TextField("프롬프트", text: Binding(
                get: { step.imagePlayground?.prompt ?? "" },
                set: { step.imagePlayground?.prompt = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
            Picker("스타일", selection: Binding(
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
            Text("변수 설정")
                .font(.headline)
            
            TextField("변수 값", text: $step.target)
                .textFieldStyle(.roundedBorder)
            
            Text("이 단계는 실행 중 이 값을 변수로 설정합니다. 매직 변수 연결은 변수 패널에서 구성합니다.")
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
            Text("코멘트")
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
            Text("설정")
                .font(.headline)
            
            TextField("제목", text: $step.title)
                .textFieldStyle(.roundedBorder)
            
            TextField("대상 (값)", text: $step.target)
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
