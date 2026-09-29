import SwiftUI

/// iOS Shortcuts 스타일 액션 카탈로그 뷰
struct ActionCatalogView: View {
    @Binding var selectedActionType: ActionType?
    @Environment(\.theme) private var theme
    @State private var searchText = ""
    @State private var selectedCategory: ActionCategory?
    @State private var isExpanded = true
    /// 미구현·스텁 액션도 "준비 중"으로 표시할지 (E-MAC-CAT-9401)
    @State private var showUnavailable = false
    
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
            
            // 구현되지 않은 액션 표시 토글 (E-MAC-CAT-9401)
            if unavailableCount > 0 {
                Button {
                    showUnavailable.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showUnavailable ? "eye.fill" : "eye.slash")
                            .font(.caption2)
                        Text(
                            showUnavailable
                                ? "ui.catalog.hide_unavailable".localizedFormat(unavailableCount)
                                : "ui.catalog.show_unavailable".localizedFormat(unavailableCount)
                        )
                        .font(.caption2)
                    }
                    .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
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
        let selectable = actionType.isSelectable
        return Button {
            // E-MAC-CAT-9401: 미구현 액션은 선택 자체를 막는다.
            // 이전에는 고른 뒤 실행해야 "미구현"을 알 수 있었다.
            guard selectable else {
                Logger.info("ActionCatalogView", "미구현 액션 선택 시도(무시): \(actionType.rawValue)")
                return
            }
            selectedActionType = actionType
        } label: {
            HStack(spacing: 10) {
                Image(systemName: actionType.systemImage)
                    .font(.body)
                    .foregroundColor(selectable ? theme.accentColor : theme.tertiaryText)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(actionType.displayName)
                        .font(.body)
                        .foregroundColor(selectable ? .primary : theme.secondaryText)
                    // 미구현은 무엇이 다른지 바로 알 수 있게 상태를 표기한다
                    if !selectable {
                        Text(badgeText(for: actionType.implementation))
                            .font(.caption2)
                            .foregroundColor(theme.secondaryText)
                    }
                }

                Spacer()

                Image(systemName: selectable ? "plus.circle" : "clock.badge.questionmark")
                    .font(.caption)
                    .foregroundColor(selectable ? theme.accentColor : theme.tertiaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .opacity(selectable ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!selectable)
    }

    /// 구현되지 않은 액션 수 (토글 문구용)
    private var unavailableCount: Int {
        ActionType.allCases.count { $0.implementation != .implemented }
    }

    /// 구현 상태 배지 문구
    private func badgeText(for implementation: ActionType.ActionImplementation) -> String {
        switch implementation {
        case .stub: return "ui.catalog.state_stub".localized
        case .planned, .implemented: return "ui.catalog.state_planned".localized
        }
    }
    
    // MARK: - 필터링

    /// 구현 완료된 액션만 기본 노출한다 (E-MAC-CAT-9401)
    ///
    /// 이전에는 153종 전부(실제 구현 28종)가 구분 없이 노출됐다. 미구현 액션을 골라도
    /// 단계 설정 창은 정상으로 열리고 저장도 되지만 실행 시 "미구현" 토스트가 뜬다.
    /// "준비 중" 항목은 `showUnavailable`를 켤 때만 접이 형태로 보인다.
    private func filteredActions(for category: ActionCategory) -> [ActionType] {
        let actions = category.actionTypes.filter { showUnavailable || $0.isSelectable }
        if searchText.isEmpty { return actions }
        return actions.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var allFilteredActions: [ActionType] {
        let base = ActionType.allCases.filter { showUnavailable || $0.isSelectable }
        return base.filter {
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
