import SwiftUI

/// 변수 패널 뷰 — iOS Shortcuts 스타일 변수 선택/관리
struct VariablePanelView: View {
    @Binding var selectedVariables: [Variable]
    @Environment(\.theme) private var theme
    @State private var searchText = ""
    @State private var selectedTab: VariableTab = .magic
    @State private var showingManualVariableCreator = false
    
    enum VariableTab: String, CaseIterable {
        case magic
        case special
        case manual
        
        var displayName: String {
            switch self {
            case .magic: return "ui.var.category_magic".localized
            case .special: return "ui.var.category_special".localized
            case .manual: return "ui.var.category_user".localized
            }
        }
        var systemImage: String {
            switch self {
            case .magic: return "wand.and.stars"
            case .special: return "star.fill"
            case .manual: return "text.cursor"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더
            HStack {
                Image(systemName: "text.badge.plus")
                    .foregroundColor(theme.accentColor)
                Text("ui.variables".localized)
                    .font(.headline)
                Spacer()
                Button {
                    showingManualVariableCreator = true
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(theme.accentColor)
                }
                .buttonStyle(.plain)
                .help("ui.var.create_help".localized)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            // 탭 선택
            Picker("", selection: $selectedTab) {
                ForEach(VariableTab.allCases, id: \.self) { tab in
                    Label(tab.displayName, systemImage: tab.systemImage).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            
            Divider()
            
            // 변수 목록
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    switch selectedTab {
                    case .magic:
                        magicVariablesSection
                    case .special:
                        specialVariablesSection
                    case .manual:
                        manualVariablesSection
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 200)
        .background(theme.primaryBackground)
        .sheet(isPresented: $showingManualVariableCreator) {
            ManualVariableCreatorSheet(variables: $selectedVariables)
        }
    }
    
    // MARK: - 마법 변수 섹션
    
    private var magicVariablesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if selectedVariables.isEmpty {
                emptyStateView(
                    icon: "wand.and.stars",
                    title: "ui.var.magic_empty".localized,
                    message: "ui.var.magic_hint".localized
                )
            } else {
                let magicVars = selectedVariables.filter { $0.type == .magic }
                if magicVars.isEmpty {
                    emptyStateView(
                        icon: "wand.and.stars",
                        title: "ui.var.magic_empty".localized,
                        message: "ui.var.magic_hint".localized
                    )
                } else {
                    ForEach(magicVars) { variable in
                        variableRow(variable)
                    }
                }
            }
        }
    }
    
    // MARK: - 특수 변수 섹션
    
    private var specialVariablesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SpecialVariable.allCases) { special in
                specialVariableRow(special)
            }
        }
    }
    
    // MARK: - 사용자 변수 섹션
    
    private var manualVariablesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            let manualVars = selectedVariables.filter { $0.type == .manual }
            if manualVars.isEmpty {
                emptyStateView(
                    icon: "text.cursor",
                    title: "ui.var.manual_empty".localized,
                    message: "ui.var.manual_hint".localized
                )
            } else {
                ForEach(manualVars) { variable in
                    variableRow(variable)
                }
            }
        }
    }
    
    // MARK: - 컴포넌트
    
    private func variableRow(_ variable: Variable) -> some View {
        Button {
            // 변수 선택 시 복사하거나 입력 필드에 삽입
        } label: {
            HStack(spacing: 8) {
                // 변수 색상 표시
                Circle()
                    .fill(variableTypeColor(variable.type))
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(variable.name)
                        .font(.caption)
                        .foregroundColor(.primary)
                    Text(variable.type.displayName)
                        .font(.caption2)
                        .foregroundColor(theme.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "doc.on.clipboard")
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func specialVariableRow(_ special: SpecialVariable) -> some View {
        Button {
            // 특수 변수 선택
        } label: {
            HStack(spacing: 8) {
                // 특수 변수 아이콘
                Circle()
                    .fill(theme.warningColor)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(special.displayName)
                        .font(.caption)
                        .foregroundColor(.primary)
                    Text(LocalizedStringKey("action.system"))
                        .font(.caption2)
                        .foregroundColor(theme.secondaryText)
                }
                
                Spacer()
                
                Text(special.tokenString)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(theme.secondaryText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(theme.secondaryText)
            Text(title)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            Text(message)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private func variableTypeColor(_ type: VariableType) -> Color {
        switch type {
        case .magic: return .blue
        case .special: return .orange
        case .manual: return .green
        }
    }
}

// MARK: - 사용자 변수 만들기 시트

struct ManualVariableCreatorSheet: View {
    @Binding var variables: [Variable]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    @State private var name = ""
    @State private var type: VariableValueType = .text
    @State private var defaultValue = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ui.var.new_variable".localized)
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(.borderless)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("ui.name".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                TextField("ui.var.name_label".localized, text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("ui.var.type".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                Picker("", selection: $type) {
                    ForEach(VariableValueType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .labelsHidden()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("ui.default_optional".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                TextField("ui.var.default_placeholder".localized, text: $defaultValue)
                    .textFieldStyle(.roundedBorder)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("ui.cancel".localized) {
                    dismiss()
                }
                Button("ui.add".localized) {
                    let variable = Variable(
                        name: name,
                        type: .manual,
                        valueType: type
                    )
                    variables.append(variable)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 350, height: 300)
    }
}

// MARK: - 변수 플 레 (단계 내 인라인 표시)

/// 단계 내에서 변수를 파란색 알약으로 표시하는 뷰
struct VariablePill: View {
    let variable: Variable
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: variableIcon)
                    .font(.caption2)
                Text(variable.name)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(pillColor.opacity(0.15))
            .foregroundColor(pillColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(pillColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var variableIcon: String {
        switch variable.type {
        case .magic: return "wand.and.stars"
        case .special: return "star.fill"
        case .manual: return "text.cursor"
        }
    }
    
    private var pillColor: Color {
        switch variable.type {
        case .magic: return .blue
        case .special: return .orange
        case .manual: return .green
        }
    }
}

// MARK: - 특수 변수 토큰 표시

/// 특수 변수를 {토큰} 형태로 표시하는 뷰
struct SpecialVariableToken: View {
    let special: SpecialVariable
    let onTap: () -> Void
    @Environment(\.theme) private var theme
    
    var body: some View {
        Button(action: onTap) {
            Text(special.tokenString)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(theme.warningColor.opacity(0.15))
                .foregroundColor(theme.warningColor)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(theme.warningColor.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
