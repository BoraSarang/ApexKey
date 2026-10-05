import SwiftUI

/// iOS Shortcuts 스타일 액션 카탈로그 뷰
struct ActionCatalogView: View {
    @Binding var selectedActionType: ActionType?
    /// 시스템 프리셋 직접 추가 — System 카테고리에서 8종을 개별 아이템으로 노출.
    /// 설정 창의 피커와 같은 값(target=프리셋 ID)을 넣으므로 정체성이 깨지지 않는다.
    @Binding var selectedSystemPreset: SystemActionType?
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
                            catalogRows(for: actionType)
                        }
                    } else if searchText.isEmpty {
                        // 모든 카테고리별로 표시
                        ForEach(ActionCategory.allCases) { category in
                            let actions = filteredActions(for: category)
                            if !actions.isEmpty {
                                categoryHeader(category)
                                ForEach(actions) { actionType in
                                    catalogRows(for: actionType)
                                }
                            }
                        }
                    } else {
                        // 검색 결과 (프리셋명 검색도 지원)
                        let results = allFilteredActions
                        let presetResults = matchingPresets
                        if results.isEmpty && presetResults.isEmpty {
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
                                // .system 단독 행은 노출하지 않는다 — 프리셋 8종으로 대체
                                if actionType != .system {
                                    actionRow(actionType)
                                }
                            }
                            ForEach(presetResults) { type in
                                systemPresetRow(type)
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

    // MARK: - 시스템 프리셋 행

    /// .system 단독 행 대신 프리셋 8종을 개별 아이템으로 노출.
    /// 고르면 설정 창 피커와 같은 값(target=프리셋 ID)이 들어가므로 정체성이 깨지지 않는다.
    @ViewBuilder
    private func catalogRows(for actionType: ActionType) -> some View {
        if actionType == .system {
            ForEach(SystemActionType.allCases) { type in
                systemPresetRow(type)
            }
        } else {
            actionRow(actionType)
        }
    }

    private func systemPresetRow(_ type: SystemActionType) -> some View {
        Button {
            selectedSystemPreset = type
        } label: {
            HStack(spacing: 10) {
                Image(systemName: type.systemImage)
                    .font(.body)
                    .foregroundColor(theme.accentColor)
                    .frame(width: 24)

                Text(type.displayName)
                    .font(.body)
                    .foregroundColor(.primary)

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
    }

    /// 검색어와 매칭되는 프리셋 — "System" 자체가 매칭되면 전체를 보여준다
    private var matchingPresets: [SystemActionType] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        if ActionType.system.displayName.localizedCaseInsensitiveContains(q)
            || "system".localizedCaseInsensitiveContains(q) {
            return SystemActionType.allCases
        }
        let matched = SystemActionType.allCases.filter {
            $0.displayName.localizedCaseInsensitiveContains(q)
                || $0.rawValue.localizedCaseInsensitiveContains(q)
        }
        return matched
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