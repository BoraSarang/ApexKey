import SwiftUI

/// 자동화 허브 — 워크플로우별 개인 자동화 트리거 목록·추가·편집
struct AutomationBrowserView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme

    @State private var editingShortcut: ShortcutItem?
    @State private var showingWorkflowPicker = false

    /// 자동화 트리거가 등록된 워크플로우 목록
    private var automatedShortcuts: [ShortcutItem] {
        store.shortcuts.filter { !$0.automations.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if store.shortcuts.isEmpty {
                emptyWorkflows
            } else if automatedShortcuts.isEmpty {
                emptyAutomations
            } else {
                contentList
            }
        }
        .frame(minWidth: 440, minHeight: 480)
        .background(theme.primaryBackground)
        .sheet(item: $editingShortcut) { shortcut in
            AutomationSettingsView(automations: automationsBinding(for: shortcut))
                .environmentObject(store)
        }
        .sheet(isPresented: $showingWorkflowPicker) {
            workflowPickerSheet
                .environmentObject(store)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.badge.clock")
                .frame(width: 36, height: 36)
                .font(.title3)
                .foregroundColor(theme.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("ui.automation.title".localized)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("ui.automation.subtitle".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - 목록

    private var contentList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    showingWorkflowPicker = true
                } label: {
                    Label("ui.automation.new".localized, systemImage: "plus")
                }
                .buttonStyle(.bordered)

                VStack(spacing: 8) {
                    ForEach(automatedShortcuts) { shortcut in
                        automationCard(shortcut)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(16)
        }
    }

    private func automationCard(_ shortcut: ShortcutItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up")
                    .foregroundColor(theme.accentColor)
                Text(shortcut.name)
                    .font(.body)
                    .fontWeight(.medium)
                Spacer()
                Button("ui.automation.edit".localized) {
                    editingShortcut = shortcut
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Divider()

            ForEach(shortcut.automations) { trigger in
                HStack(spacing: 8) {
                    Image(systemName: trigger.systemImage)
                        .frame(width: 18)
                        .foregroundColor(color(for: trigger))
                    Text(trigger.displayName)
                        .font(.callout)
                    Spacer()
                    Text(trigger.category.displayName + " · " + trigger.minimumOSVersion)
                        .font(.caption2)
                        .foregroundColor(theme.secondaryText)
                }
            }
        }
        .padding(10)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 워크플로우 선택 (새 자동화)

    private var workflowPickerSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("ui.automation.choose_workflow".localized)
                    .font(.headline)
                Spacer()
                Button("ui.cancel".localized) { showingWorkflowPicker = false }
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(store.shortcuts) { shortcut in
                        Button {
                            let selected = shortcut
                            showingWorkflowPicker = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                editingShortcut = selected
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "square.stack.3d.up")
                                    .foregroundColor(theme.accentColor)
                                Text(shortcut.name)
                                    .font(.body)
                                    .foregroundColor(theme.primaryText)
                                Spacer()
                                Text("ui.automation.trigger_count".localizedFormat(shortcut.automations.count))
                                    .font(.caption2)
                                    .foregroundColor(theme.secondaryText)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(theme.secondaryText)
                            }
                            .padding(10)
                            .background(theme.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 420, height: 480)
        .background(theme.primaryBackground)
    }

    // MARK: - 빈 상태

    private var emptyWorkflows: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.badge.clock")
                .font(.system(size: 40))
                .foregroundColor(theme.secondaryText)
            Text("ui.automation.no_workflows".localized)
                .font(.callout)
                .foregroundColor(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyAutomations: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.badge.clock")
                .font(.system(size: 40))
                .foregroundColor(theme.secondaryText)
            Text("ui.automation.no_automations".localized)
                .font(.callout)
                .foregroundColor(theme.secondaryText)
            Button {
                showingWorkflowPicker = true
            } label: {
                Label("ui.automation.new".localized, systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 바인딩/색상

    private func automationsBinding(for shortcut: ShortcutItem) -> Binding<[AutomationTrigger]> {
        Binding(
            get: { store.shortcuts.first(where: { $0.id == shortcut.id })?.automations ?? shortcut.automations },
            set: { newValue in
                store.updateShortcutAutomations(shortcut, automations: newValue)
            }
        )
    }

    private func color(for trigger: AutomationTrigger) -> Color {
        switch trigger.category {
        case .time: return .blue
        case .filesystem: return .green
        case .hardware: return .gray
        case .network: return .teal
        case .power: return .yellow
        case .system: return .indigo
        }
    }
}