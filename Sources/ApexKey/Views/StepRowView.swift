import SwiftUI

/// iOS Shortcuts 스타일 단계 행 — 드래그 앤 드롭, 인라인 변수 표시
struct StepRowView: View {
    let step: ShortcutStep
    let index: Int
    let totalSteps: Int
    let isEditing: Bool
    let isSelected: Bool
    
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onDelete: (() -> Void)?
    var onDuplicate: (() -> Void)?
    var onSelect: (() -> Void)?
    var onToggleSkip: (() -> Void)?
    
    @State private var isHovered = false
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            // 드래그 핸들 (편집 모드일 때만)
            if isEditing {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                    .frame(width: 12)
            }
            
            // 단계 번호
            Text("\(index + 1)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(theme.secondaryText)
                .frame(width: 18)
            
            // 액션 아이콘 + 색상
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(actionColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: step.type.systemImage)
                    .font(.system(.caption))
                    .foregroundColor(actionColor)
            }
            
            // 단계 내용
            VStack(alignment: .leading, spacing: 2) {
                // 단계 타입 + 요약
                HStack(spacing: 6) {
                    Text(step.type.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(theme.primaryText)
                    
                    if step.isSkipped {
                        Text("ui.skip".localized)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(theme.warningColor.opacity(0.15))
                            .foregroundColor(theme.warningColor)
                            .clipShape(Capsule())
                    }
                }
                
                // 단계 요약 (타겟 정보)
                Text(step.summary)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                    .lineLimit(1)
                
                // 변수 표시 (있는 경우)
                if let variables = step.outputVariables, !variables.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(variables) { variable in
                                VariablePill(variable: variable, isSelected: false) {}
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // 편집 모드 컨트롤
            if isEditing {
                HStack(spacing: 4) {
                    // 위로 이동
                    Button(action: { onMoveUp?() }) {
                        Image(systemName: "chevron.up")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .disabled(index == 0)
                    .help("ui.step.move_up".localized)
                    
                    // 아래로 이동
                    Button(action: { onMoveDown?() }) {
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .disabled(index == totalSteps - 1)
                    .help("ui.step.move_down".localized)
                    
                    // 복제
                    Button(action: { onDuplicate?() }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .help("ui.step.duplicate".localized)
                    
                    // 스킵 토글
                    Button(action: { onToggleSkip?() }) {
                        Image(systemName: step.isSkipped ? "forward.fill" : "forward")
                            .font(.caption2)
                            .foregroundColor(step.isSkipped ? theme.warningColor : theme.secondaryText)
                    }
                    .buttonStyle(.borderless)
                    .help(step.isSkipped ? "ui.step.unskip".localized : "ui.skip".localized)
                    
                    // 삭제
                    Button(action: { onDelete?() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(theme.secondaryText)
                    }
                    .buttonStyle(.borderless)
                    .help("ui.delete".localized)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? theme.accentColor.opacity(0.1) : theme.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? theme.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onSelect?()
        }
    }
    
    // MARK: - 액션별 색상
    
    private var actionColor: Color {
        switch step.type.category {
        case .essential: return .blue
        case .scripting: return .purple
        case .media: return .pink
        case .documents: return .green
        case .location: return .teal
        case .content: return .orange
        case .accessories: return .gray
        case .flowControl: return .indigo
        case .variables: return .cyan
        case .ai: return .mint
        case .appIntents: return .red
        case .automation: return .yellow
        }
    }
}

// MARK: - 블록 구조 단계 (If/Repeat/ChooseFromMenu)

/// 중첩된 블록 구조를 표시하는 단계 행
struct BlockStepRowView: View {
    let step: ShortcutStep
    let index: Int
    let totalSteps: Int
    let isEditing: Bool
    let nestingLevel: Int
    
    var onSelect: (() -> Void)?
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 메인 단계 행
            StepRowView(
                step: step,
                index: index,
                totalSteps: totalSteps,
                isEditing: isEditing,
                isSelected: false,
                onSelect: onSelect
            )
            
            // 중첩된 내용 (-indent)
            if let nestedSteps = step.nestedSteps, !nestedSteps.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(nestedSteps.enumerated()), id: \.element.id) { nestedIndex, nestedStep in
                        HStack(spacing: 0) {
                            // 들여쓰기 표시
                            Rectangle()
                                .fill(blockBorderColor.opacity(0.3))
                                .frame(width: 2)
                            
                            StepRowView(
                                step: nestedStep,
                                index: nestedIndex,
                                totalSteps: nestedSteps.count,
                                isEditing: isEditing,
                                isSelected: false
                            )
                            .padding(.leading, CGFloat(nestingLevel + 1) * 16)
                        }
                    }
                }
            }
            
            // 블록 종료 표시
            if step.isBlockStructure {
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(blockBorderColor.opacity(0.3))
                        .frame(width: 2)
                    Text(blockEndLabel)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                    Spacer()
                }
                .padding(.leading, CGFloat(nestingLevel) * 16 + 12)
            }
        }
    }
    
    private var blockBorderColor: Color {
        switch step.type {
        case .ifElse: return .indigo
        case .repeatLoop, .repeatEach: return .purple
        case .chooseFromMenu: return .orange
        default: return .gray
        }
    }
    
    private var blockEndLabel: String {
        switch step.type {
        case .ifElse: return "ui.step.if_end".localized
        case .repeatLoop, .repeatEach: return "ui.step.repeat_end".localized
        case .chooseFromMenu: return "ui.step.menu_end".localized
        default: return ""
        }
    }
}

// MARK: - 단계 연결선

/// 단계 간의 연결을 시각적으로 표시하는 뷰
struct StepConnectorView: View {
    let index: Int
    let isLast: Bool
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack(spacing: 0) {
            Spacer()
                .frame(width: 23) // 아이콘 중앙 정렬
            
            VStack(spacing: 0) {
                Rectangle()
                    .fill(theme.secondaryBorder.opacity(0.4))
                    .frame(width: 1, height: 8)
                
                if !isLast {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 6))
                        .foregroundColor(theme.secondaryText.opacity(0.3))
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - 단계 목록 뷰

/// 전체 단계 목록을 표시하는 뷰
struct StepListView: View {
    let steps: [ShortcutStep]
    let isEditing: Bool
    @Binding var selectedStepID: UUID?
    
    var onMove: ((IndexSet, Int) -> Void)?
    var onDelete: ((IndexSet) -> Void)?
    var onDuplicate: ((Int) -> Void)?
    var onToggleSkip: ((Int) -> Void)?
    var onSelect: ((ShortcutStep) -> Void)?
    @Environment(\.theme) private var theme

    private func handleSelect(_ step: ShortcutStep) {
        selectedStepID = step.id
        onSelect?(step)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if steps.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            VStack(spacing: 0) {
                                // 단계 행
                                if step.isBlockStructure {
                                    BlockStepRowView(
                                        step: step,
                                        index: index,
                                        totalSteps: steps.count,
                                        isEditing: isEditing,
                                        nestingLevel: 0,
                                        onSelect: { handleSelect(step) }
                                    )
                                } else {
                                    StepRowView(
                                        step: step,
                                        index: index,
                                        totalSteps: steps.count,
                                        isEditing: isEditing,
                                        isSelected: selectedStepID == step.id,
                                        onMoveUp: { onMove?([index], index - 1) },
                                        onMoveDown: { onMove?([index], index + 1) },
                                        onDelete: { onDelete?([index]) },
                                        onDuplicate: { onDuplicate?(index) },
                                        onSelect: { handleSelect(step) },
                                        onToggleSkip: { onToggleSkip?(index) }
                                    )
                                }
                                
                                // 연결선
                                if index < steps.count - 1 {
                                    StepConnectorView(index: index, isLast: false)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.number")
                .font(.title2)
                .foregroundColor(theme.secondaryText)
            Text("ui.station.no_steps".localized)
                .font(.subheadline)
                .foregroundColor(theme.secondaryText)
            Text("ui.step.empty_hint".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
}
