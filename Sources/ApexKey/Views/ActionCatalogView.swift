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
                Text("액션 추가")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            // 검색바
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.secondaryText)
                TextField("검색", text: $searchText)
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
                    categoryChip(nil, label: "전체")
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
                                Text("검색 결과 없음")
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
                Button("완료") {
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
            Text("실행할 앱을 선택하세요")
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            // 실제 구현에서는 AppPicker 뷰 사용
            TextField("번들 ID", text: $target)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var scriptEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("셸 명령을 입력하세요")
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
            Text("URL을 입력하세요")
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("https://example.com", text: $target)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var fileEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("파일/폴더 경로를 입력하세요")
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            HStack {
                TextField("경로", text: $target)
                    .textFieldStyle(.roundedBorder)
                Button("찾기") {
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
            Text("시스템 동작을 선택하세요")
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
            Text("붙여넣을 텍스트를 입력하세요 (비우면 클립보드)")
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("텍스트", text: $target)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var waitEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("대기 시간을 초 단위로 입력하세요")
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("1.0", text: $target)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var menuCommandInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("메뉴 명령은 액션 카탈로그에서 직접 선택합니다")
                .font(.caption)
                .foregroundColor(theme.secondaryText)
        }
    }
    
    private var coordinateEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("x,y 좌표를 입력하세요 (예: 500,400)")
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("500,400", text: $target)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var macroEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("키코드를 쉼표로 구분하여 입력하세요")
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("36,36", text: $target)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var pauseInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("⌘⇧↩를 누를 때까지 대기합니다")
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            Text("이 액션은 추가 설정이 필요하지 않습니다")
                .font(.caption)
                .foregroundColor(theme.secondaryText)
        }
    }
    
    private var genericEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("대상을 입력하세요")
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("대상", text: $target)
                .textFieldStyle(.roundedBorder)
        }
    }
}
