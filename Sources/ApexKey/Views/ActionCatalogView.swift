import SwiftUI

/// iOS Shortcuts 스타일 액션 카탈로그 뷰
struct ActionCatalogView: View {
    @Binding var selectedActionType: ActionType?
    @Environment(\.theme) private var theme
    @State private var searchText = ""
    @State private var selectedCategory: ActionCategory?
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(theme.accentColor)
                Text("ui.catalog.add_action".localized)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            // 검색바
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.secondaryText)
                TextField("ui.search".localized, text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(theme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // 카테고리 선택
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    categoryChip(nil, label: "ui.catalog.all".localized)
                    ForEach(ActionCategory.allCases) { category in
                        categoryChip(category, label: category.displayName)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            
            Divider()
            
            // 액션 목록
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let category = selectedCategory {
                        // 특정 카테고리의 액션 표시
                        ForEach(filteredActions(for: category)) { actionType in
                            actionRow(actionType)
                        }
                    } else if searchText.isEmpty {
                        // 모든 카테고리별로 표시
                        ForEach(ActionCategory.allCases) { category in
                            let actions = filteredActions(for: category)
                            if !actions.isEmpty {
                                categoryHeader(category)
                                ForEach(actions) { actionType in
                                    actionRow(actionType)
                                }
                            }
                        }
                    } else {
                        // 검색 결과
                        let results = allFilteredActions
                        if results.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.title2)
                                    .foregroundColor(theme.secondaryText)
                                Text("ui.catalog.no_results".localized)
                                    .font(.caption)
                                    .foregroundColor(theme.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                        } else {
                            ForEach(results) { actionType in
                                actionRow(actionType)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 230)
        .background(theme.primaryBackground)
    }
    
    // MARK: - 컴포넌트
    
    private func categoryChip(_ category: ActionCategory?, label: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedCategory = selectedCategory == category ? nil : category
            }
        } label: {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    selectedCategory == category
                        ? theme.accentColor.opacity(0.15)
                        : theme.inputBackground
                )
                .foregroundColor(selectedCategory == category ? theme.accentColor : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private func categoryHeader(_ category: ActionCategory) -> some View {
        HStack(spacing: 6) {
            Image(systemName: category.systemImage)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            Text(category.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(theme.secondaryText)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    private func actionRow(_ actionType: ActionType) -> some View {
        Button {
            selectedActionType = actionType
        } label: {
            HStack(spacing: 10) {
                Image(systemName: actionType.systemImage)
                    .font(.body)
                    .foregroundColor(theme.accentColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(actionType.displayName)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Image(systemName: "plus.circle")
                    .font(.caption)
                    .foregroundColor(theme.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            // hover 효과는 SwiftUI 4+에서 가능
        }
    }
    
    // MARK: - 필터링
    
    private func filteredActions(for category: ActionCategory) -> [ActionType] {
        let actions = category.actionTypes
        if searchText.isEmpty { return actions }
        return actions.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var allFilteredActions: [ActionType] {
        ActionType.allCases.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - 액션 상세 설정 시트

/// 액션별 상세 설정 뷰
struct ActionDetailView: View {
    let actionType: ActionType
    @Binding var target: String
    @Binding var title: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: actionType.systemImage)
                    .font(.title2)
                    .foregroundColor(theme.accentColor)
                Text(actionType.displayName)
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
            
            switch actionType {
            case .launchApp:
                appPicker
            case .script:
                scriptEditor
            case .url:
                urlEditor
            case .file:
                fileEditor
            case .system:
                systemPicker
            case .paste:
                pasteEditor
            case .wait:
                waitEditor
            case .menuCommand:
                menuCommandInfo
            case .coordinateClick:
                coordinateEditor
            case .macro:
                macroEditor
            case .pauseUntilInput:
                pauseInfo
            default:
                genericEditor
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("ui.done".localized) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400, height: 350)
    }
    
    // MARK: - 액션별 편집기
    
    private var appPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ui.app_detail.run_app_prompt".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            // 실제 구현에서는 AppPicker 뷰 사용
            TextField("ui.app_detail.bundle_id".localized, text: $target)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var scriptEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ui.app_detail.shell_prompt".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextEditor(text: $target)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(theme.secondaryBorder)
                )
        }
    }
    
    private var urlEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ui.app_detail.url_prompt".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("https://example.com", text: $target)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var fileEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ui.app_detail.file_prompt".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            HStack {
                TextField("ui.path".localized, text: $target)
                    .textFieldStyle(.roundedBorder)
                Button("ui.browse".localized) {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = true
                    if panel.runModal() == .OK, let url = panel.url {
                        target = url.path
                        title = url.lastPathComponent
                    }
                }
            }
        }
    }
    
    private var systemPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ui.app_detail.select_system".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            ForEach(SystemActionType.allCases) { type in
                Button {
                    target = type.rawValue
                    title = type.displayName
                } label: {
                    HStack {
                        Text(type.displayName)
                        Spacer()
                        if target == type.rawValue {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(theme.accentColor)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var pasteEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ui.app_detail.clipboard_prompt".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("ui.text".localized, text: $target)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var waitEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ui.app_detail.wait_prompt".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("1.0", text: $target)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var menuCommandInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ui.app_detail.menu_note".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
        }
    }
    
    private var coordinateEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ui.app_detail.coordinate_prompt".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("500,400", text: $target)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var macroEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ui.app_detail.keycode_prompt".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("36,36", text: $target)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var pauseInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ui.app_detail.wait_until".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            Text("ui.app_detail.no_settings".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
        }
    }
    
    private var genericEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ui.app_detail.target_prompt".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("ui.target".localized, text: $target)
                .textFieldStyle(.roundedBorder)
        }
    }
}
