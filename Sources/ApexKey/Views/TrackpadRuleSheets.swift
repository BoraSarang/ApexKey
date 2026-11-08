import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - 공통 조각

/// 시트 상단 헤더 (제목 + 설명 + 닫기)
private struct TrackpadSheetHeader: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("trackpad.cancel".localized)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// 그룹 상자 (제목 + 내용)
private struct TrackpadSheetGroup<Content: View>: View {
    @Environment(\.theme) private var theme
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(theme.tertiaryText)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.tertiaryBackground.opacity(0.55))
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 4)
        }
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }
}

/// 라벨 + 컨트롤 + 힌트 한 줄
private struct TrackpadField<Content: View>: View {
    @Environment(\.theme) private var theme
    let label: String
    let hint: String?
    let content: Content

    init(_ label: String, hint: String? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.hint = hint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 10) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(theme.primaryText)
                Spacer(minLength: 12)
                content
            }
            if let hint {
                Text(hint)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 5)
    }
}

/// 상단 요약 노트
private struct TrackpadSummaryNote: View {
    @Environment(\.theme) private var theme
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundColor(theme.accentColor)
            Text(text)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(theme.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// 경고 노트
private struct TrackpadWarningNote: View {
    @Environment(\.theme) private var theme
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.caption)
                .foregroundColor(theme.warningColor)
            Text(text)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(theme.warningColor.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// 시트 하단 버튼 줄
private struct TrackpadSheetFooter<Leading: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let saveEnabled: Bool
    let onSave: () -> Void
    let leading: Leading

    init(saveEnabled: Bool = true, onSave: @escaping () -> Void, @ViewBuilder leading: () -> Leading) {
        self.saveEnabled = saveEnabled
        self.onSave = onSave
        self.leading = leading()
    }

    var body: some View {
        HStack(spacing: 8) {
            leading
            Spacer()
            Button("trackpad.cancel".localized) { dismiss() }
            Button("trackpad.save".localized) { onSave() }
                .buttonStyle(.borderedProminent)
                .disabled(!saveEnabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(theme.tertiaryBackground.opacity(0.35))
    }
}

// MARK: - 추가 선택

struct TrackpadChooserSheet: View {
    @Environment(\.theme) private var theme
    enum Choice { case slider, gesture }

    let onChoose: (Choice) -> Void

    var body: some View {
        VStack(spacing: 0) {
            TrackpadSheetHeader(
                title: "trackpad.sheet.chooser_title".localized,
                subtitle: "trackpad.sheet.chooser_desc".localized
            )
            Divider()
            VStack(spacing: 8) {
                choiceRow(
                    icon: "arrow.up.and.down",
                    title: "trackpad.chooser.slider".localized,
                    detail: "trackpad.chooser.slider_desc".localized
                ) { onChoose(.slider) }
                choiceRow(
                    icon: "hand.tap",
                    title: "trackpad.chooser.gesture".localized,
                    detail: "trackpad.chooser.gesture_desc".localized
                ) { onChoose(.gesture) }
            }
            .padding(16)
        }
        .frame(width: 470)
        .background(theme.primaryBackground)
    }

    private func choiceRow(
        icon: String,
        title: String,
        detail: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(theme.accentColor)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body).fontWeight(.medium)
                    Text(detail)
                        .font(.caption2)
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(theme.tertiaryText)
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - 에지 슬라이더 시트

struct TrackpadSliderSheet: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme

    @State private var rule: EdgeSliderRule
    private let isEditing: Bool

    init(rule: EdgeSliderRule, isEditing: Bool) {
        _rule = State(initialValue: rule)
        self.isEditing = isEditing
    }

    private var canSave: Bool {
        if rule.target == .shortcut { return rule.shortcutID != nil }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            TrackpadSheetHeader(
                title: (isEditing
                        ? "trackpad.sheet.slider_edit".localized
                        : "trackpad.sheet.slider_add".localized),
                subtitle: "trackpad.sheet.slider_desc".localized
            )
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TrackpadSummaryNote(text: summary)

                    TrackpadSheetGroup(title: "trackpad.group.behavior".localized) {
                        TrackpadField("trackpad.field.edge".localized, hint: "trackpad.hint.edge".localized) {
                            edgePicker
                        }
                        TrackpadField("trackpad.field.fingers".localized, hint: "trackpad.hint.fingers".localized) {
                            Picker("", selection: $rule.fingers) {
                                ForEach(1...3, id: \.self) { count in
                                    Text("\(count)").tag(count)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 140)
                        }
                        TrackpadField("trackpad.field.axis".localized, hint: "trackpad.hint.axis".localized) {
                            Text(rule.edge.isVertical
                                 ? "trackpad.axis.vertical".localized
                                 : "trackpad.axis.horizontal".localized)
                                .font(.caption2)
                                .foregroundColor(theme.secondaryText)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(theme.tertiaryBackground)
                                .clipShape(Capsule())
                        }
                        TrackpadField("trackpad.field.target".localized, hint: targetHint) {
                            Picker("", selection: $rule.target) {
                                ForEach(SliderTarget.allCases) { target in
                                    Text(target.displayName).tag(target)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 190)
                        }
                        if rule.target == .shortcut {
                            TrackpadField("trackpad.field.shortcut".localized, hint: "trackpad.hint.target.shortcut".localized) {
                                if store.shortcuts.isEmpty {
                                    Text("trackpad.action.none".localized)
                                        .font(.caption2)
                                        .foregroundColor(theme.errorColor)
                                } else {
                                    Picker("", selection: $rule.shortcutID) {
                                        Text("trackpad.action.none".localized).tag(UUID?.none)
                                        ForEach(store.shortcuts) { shortcut in
                                            Text(shortcut.name).tag(Optional(shortcut.id))
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(width: 220)
                                }
                            }
                        }
                        TrackpadField("trackpad.field.sensitivity".localized, hint: "trackpad.hint.sensitivity".localized) {
                            HStack(spacing: 8) {
                                Slider(value: $rule.sensitivity, in: 0.5...2.0, step: 0.1)
                                    .frame(width: 160)
                                Text("trackpad.sensitivity.value".localizedFormat(rule.sensitivity))
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .foregroundColor(theme.secondaryText)
                                    .frame(width: 48, alignment: .trailing)
                            }
                        }
                        TrackpadField("trackpad.field.invert".localized, hint: "trackpad.hint.invert".localized) {
                            Toggle("", isOn: $rule.inverted)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                    }

                    TrackpadSheetGroup(title: "trackpad.group.recognition".localized) {
                        TrackpadField("trackpad.field.edge_width".localized, hint: "trackpad.hint.edge_width".localized) {
                            HStack(spacing: 8) {
                                Slider(value: $rule.edgeWidth, in: 0.06...0.25, step: 0.01)
                                    .frame(width: 160)
                                Text(TrackpadFormatting.percent(rule.edgeWidth))
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .foregroundColor(theme.secondaryText)
                                    .frame(width: 48, alignment: .trailing)
                            }
                        }
                        TrackpadField("trackpad.field.threshold".localized, hint: "trackpad.hint.threshold".localized) {
                            HStack(spacing: 8) {
                                Slider(value: $rule.startThreshold, in: 0.02...0.12, step: 0.01)
                                    .frame(width: 160)
                                Text(TrackpadFormatting.percent(rule.startThreshold))
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .foregroundColor(theme.secondaryText)
                                    .frame(width: 48, alignment: .trailing)
                            }
                        }
                        TrackpadField("trackpad.field.cooldown".localized, hint: "trackpad.hint.cooldown".localized) {
                            HStack(spacing: 8) {
                                Slider(value: $rule.cooldown, in: 0.1...0.6, step: 0.025)
                                    .frame(width: 160)
                                Text(TrackpadFormatting.milliseconds(rule.cooldown))
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .foregroundColor(theme.secondaryText)
                                    .frame(width: 48, alignment: .trailing)
                            }
                        }
                        TrackpadField("trackpad.field.thumb".localized, hint: "trackpad.hint.thumb".localized) {
                            Toggle("", isOn: $rule.ignoreThumb)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                        TrackpadField("trackpad.field.suppress".localized, hint: "trackpad.hint.suppress".localized) {
                            Toggle("", isOn: $rule.suppressScroll)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                    }

                    if rule.target == .brightness {
                        TrackpadWarningNote(text: "trackpad.warning.brightness".localized)
                    }
                }
                .padding(16)
            }
            Divider()
            TrackpadSheetFooter(saveEnabled: canSave, onSave: save) {
                if isEditing {
                    Button("trackpad.delete".localized, role: .destructive) {
                        store.removeTrackpadSlider(id: rule.id)
                        TrackpadEngine.shared.refreshRules()
                        dismiss()
                    }
                }
                Button("trackpad.test".localized) {
                    TrackpadEngine.shared.runTest(rule)
                }
            }
        }
        .frame(width: 640, height: 660)
        .background(theme.primaryBackground)
    }

    @Environment(\.dismiss) private var dismiss

    private var summary: String {
        var target = rule.target.displayName
        if rule.target == .shortcut, let id = rule.shortcutID,
           let shortcut = store.shortcuts.first(where: { $0.id == id }) {
            target = shortcut.name
        }
        let axis = rule.edge.isVertical
            ? "trackpad.axis.vertical".localized
            : "trackpad.axis.horizontal".localized
        return "trackpad.sheet.slider_summary".localizedFormat(
            rule.edge.displayName, TrackpadFormatting.fingerWord(rule.fingers), axis, target
        )
    }

    private var targetHint: String {
        switch rule.target {
        case .volume: return "trackpad.hint.target.volume".localized
        case .brightness: return "trackpad.hint.target.brightness".localized
        case .shortcut: return "trackpad.hint.target.shortcut".localized
        }
    }

    private var edgePicker: some View {
        VStack(spacing: 3) {
            edgeButton(.top, icon: "arrow.up")
            HStack(spacing: 3) {
                edgeButton(.left, icon: "arrow.left")
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.tertiaryBackground)
                    .frame(width: 42, height: 24)
                edgeButton(.right, icon: "arrow.right")
            }
            edgeButton(.bottom, icon: "arrow.down")
        }
    }

    private func edgeButton(_ edge: TrackpadEdge, icon: String) -> some View {
        Button {
            rule.edge = edge
        } label: {
            Image(systemName: icon)
                .font(.caption2)
                .frame(width: 42, height: 24)
                .background(rule.edge == edge ? theme.accentColor : theme.tertiaryBackground)
                .foregroundColor(rule.edge == edge ? theme.primaryBackground : theme.secondaryText)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(edge.displayName)
    }

    private func save() {
        store.upsertTrackpadSlider(rule)
        TrackpadEngine.shared.refreshRules()
        dismiss()
    }
}

// MARK: - 제스처 시트

struct TrackpadGestureSheet: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var rule: GestureRule
    private let isEditing: Bool

    init(rule: GestureRule, isEditing: Bool) {
        _rule = State(initialValue: rule)
        self.isEditing = isEditing
    }

    var body: some View {
        VStack(spacing: 0) {
            TrackpadSheetHeader(
                title: (isEditing
                        ? "trackpad.sheet.gesture_edit".localized
                        : "trackpad.sheet.gesture_add".localized),
                subtitle: "trackpad.sheet.gesture_desc".localized
            )
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TrackpadSummaryNote(
                        text: rule.gestureSummary + " → " + rule.actionSummary { store.trackpadActionName($0) }
                    )

                    TrackpadSheetGroup(title: "trackpad.group.gesture".localized) {
                        TrackpadField("trackpad.field.kind".localized, hint: "trackpad.hint.kind".localized) {
                            Picker("", selection: $rule.kind) {
                                ForEach(GestureKind.allCases) { kind in
                                    Text(kind.displayName).tag(kind)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 150)
                        }
                        TrackpadField("trackpad.field.fingers".localized, hint: "trackpad.hint.fingers_gesture".localized) {
                            Picker("", selection: $rule.fingers) {
                                ForEach(2...5, id: \.self) { count in
                                    Text("\(count)").tag(count)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 180)
                        }
                        if rule.kind == .swipe {
                            TrackpadField("trackpad.field.direction".localized, hint: "trackpad.hint.direction".localized) {
                                Picker("", selection: $rule.direction) {
                                    ForEach(GestureDirection.allCases) { direction in
                                        Text(direction.symbol).tag(direction)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                                .frame(width: 170)
                            }
                            TrackpadField("trackpad.field.repeat".localized, hint: "trackpad.hint.repeat".localized) {
                                Toggle("", isOn: $rule.repeats)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                    .controlSize(.small)
                            }
                        }
                    }

                    TrackpadSheetGroup(title: "trackpad.group.execute".localized) {
                        TrackpadField("trackpad.field.action".localized, hint: "trackpad.hint.action".localized) {
                            Picker("", selection: $rule.action.kind) {
                                ForEach(GestureActionKind.allCases) { kind in
                                    Text(shortActionName(kind)).tag(kind)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 320)
                        }

                        switch rule.action.kind {
                        case .workflow:
                            TrackpadField("trackpad.field.target".localized, hint: "trackpad.hint.target_pick".localized) {
                                if store.shortcuts.isEmpty {
                                    Text("trackpad.action.none".localized)
                                        .font(.caption2)
                                        .foregroundColor(theme.errorColor)
                                } else {
                                    Picker("", selection: $rule.action.shortcutID) {
                                        Text("trackpad.action.none".localized).tag(UUID?.none)
                                        ForEach(store.shortcuts) { shortcut in
                                            Text(shortcut.name).tag(Optional(shortcut.id))
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(width: 230)
                                }
                            }
                        case .hotkey:
                            TrackpadField("trackpad.field.target".localized, hint: "trackpad.hint.hotkey_pick".localized) {
                                if store.bindings.isEmpty {
                                    Text("trackpad.action.none".localized)
                                        .font(.caption2)
                                        .foregroundColor(theme.errorColor)
                                } else {
                                    Picker("", selection: $rule.action.bindingID) {
                                        Text("trackpad.action.none".localized).tag(UUID?.none)
                                        ForEach(store.bindings) { binding in
                                            Text(bindingLabel(binding)).tag(Optional(binding.id))
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(width: 250)
                                }
                            }
                        case .menu:
                            TrackpadMenuPicker(action: $rule.action)
                        case .system:
                            TrackpadSystemActionPicker(action: $rule.action)
                        }
                    }

                    TrackpadSheetGroup(title: "trackpad.group.scope".localized) {
                        TrackpadField("trackpad.field.scope".localized, hint: scopeHint) {
                            Picker("", selection: $rule.scope) {
                                ForEach(GestureScope.allCases) { scope in
                                    Text(scope.displayName).tag(scope)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 170)
                        }
                        if rule.scope == .apps {
                            TrackpadAppScopePicker(selected: $rule.appBundleIDs)
                        }
                    }

                    TrackpadWarningNote(text: "trackpad.warning.duplicate".localized)
                }
                .padding(16)
            }
            Divider()
            TrackpadSheetFooter(saveEnabled: canSave, onSave: save) {
                if isEditing {
                    Button("trackpad.delete".localized, role: .destructive) {
                        store.removeTrackpadGesture(id: rule.id)
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 640, height: 680)
        .background(theme.primaryBackground)
    }

    private var canSave: Bool {
        switch rule.action.kind {
        case .workflow:
            return rule.action.shortcutID != nil
        case .hotkey:
            return rule.action.bindingID != nil
        case .menu:
            return !(rule.action.menuTitle ?? "").isEmpty && !(rule.action.menuBundleID ?? "").isEmpty
        case .system:
            guard let type = rule.action.systemAction else { return false }
            if type.requiresParameter { return !(rule.action.systemText ?? "").isEmpty }
            return true
        }
    }

    private var scopeHint: String {
        rule.scope == .global
            ? "trackpad.hint.scope".localized
            : "trackpad.hint.scope_apps".localized
    }

    private func shortActionName(_ kind: GestureActionKind) -> String {
        switch kind {
        case .workflow: return "trackpad.action.workflow".localized
        case .hotkey: return "trackpad.action.hotkey".localized
        case .menu: return "trackpad.action.menu".localized
        case .system: return "trackpad.action.system".localized
        }
    }

    private func bindingLabel(_ binding: HotKeyBinding) -> String {
        let combo = binding.combo.displayString
        if binding.title.isEmpty { return combo }
        return combo.isEmpty ? binding.title : "\(combo) — \(binding.title)"
    }

    private func save() {
        store.upsertTrackpadGesture(rule)
        dismiss()
    }
}

// MARK: - 메뉴 항목 선택

private struct TrackpadMenuPicker: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme

    @Binding var action: GestureAction

    @State private var apps: [AppItem] = []
    @State private var flatItems: [FlatMenuItem] = []
    @State private var isLoading = false
    @State private var loadMessage: String?

    private struct FlatMenuItem: Identifiable {
        let id: UUID
        let item: MenuItem
        let depth: Int
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TrackpadField("trackpad.field.app".localized, hint: "trackpad.hint.menu_app".localized) {
                HStack(spacing: 6) {
                    Menu {
                        if apps.isEmpty {
                            Text("trackpad.menu.not_running".localized)
                        } else {
                            ForEach(apps) { app in
                                Button(app.name) {
                                    action.menuBundleID = app.bundleID
                                    action.menuTitle = nil
                                    action.menuPath = []
                                }
                            }
                        }
                    } label: {
                        Text(currentAppName)
                            .lineLimit(1)
                    }
                    .frame(width: 180)
                    Button {
                        reloadApps()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .controlSize(.small)
                    .help("trackpad.reload".localized)
                }
            }

            TrackpadField("trackpad.field.menu".localized, hint: "trackpad.hint.menu_path".localized) {
                if isLoading {
                    ProgressView().controlSize(.mini)
                } else {
                    Text(selectedMenuLabel)
                        .font(.caption2)
                        .foregroundColor(theme.secondaryText)
                        .lineLimit(1)
                }
            }

            if !isLoading, let message = loadMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
                    .padding(.bottom, 5)
            }

            if !flatItems.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(flatItems) { entry in
                            menuRow(entry)
                        }
                    }
                    .padding(4)
                }
                .frame(height: 150)
                .background(theme.tertiaryBackground.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.bottom, 6)
            }
        }
        .onAppear {
            reloadApps()
            if let bundleID = action.menuBundleID, !bundleID.isEmpty {
                loadMenus(bundleID: bundleID)
            }
        }
        .onChange(of: action.menuBundleID) { _, newValue in
            guard let newValue, !newValue.isEmpty else {
                flatItems = []
                return
            }
            loadMenus(bundleID: newValue)
        }
    }

    private var currentAppName: String {
        guard let bundleID = action.menuBundleID, !bundleID.isEmpty else {
            return "trackpad.menu.choose_app".localized
        }
        return apps.first(where: { $0.bundleID == bundleID })?.name
            ?? ConfigStore.appName(for: bundleID)
            ?? bundleID
    }

    private var selectedMenuLabel: String {
        let path = action.menuPath
        if !path.isEmpty { return path.joined(separator: " › ") }
        return action.menuTitle ?? "trackpad.menu.none".localized
    }

    private func menuRow(_ entry: FlatMenuItem) -> some View {
        let isSelected = entry.item.menuPath == action.menuPath && entry.item.title == action.menuTitle
        return Button {
            action.menuTitle = entry.item.title
            action.menuPath = entry.item.menuPath
        } label: {
            HStack(spacing: 6) {
                Text(entry.item.title)
                    .lineLimit(1)
                Spacer(minLength: 6)
                if !entry.item.keyEquivalentDisplay.isEmpty {
                    Text(entry.item.keyEquivalentDisplay)
                        .font(.caption2)
                        .monospaced()
                        .foregroundColor(theme.tertiaryText)
                }
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .foregroundColor(theme.accentColor)
                }
            }
            .font(.caption)
            .padding(.leading, CGFloat(entry.depth) * 12 + 6)
            .padding(.trailing, 6)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(isSelected ? theme.accentColor.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    private func reloadApps() {
        apps = store.runningAppsForMenuPicker()
    }

    private func loadMenus(bundleID: String) {
        isLoading = true
        loadMessage = nil
        flatItems = []
        DispatchQueue.global(qos: .userInitiated).async {
            let items = MenuEnumerator.shared.enumerateMenuItems(bundleID: bundleID)
            DispatchQueue.main.async {
                guard action.menuBundleID == bundleID else { return }
                isLoading = false
                if items.isEmpty {
                    loadMessage = PermissionHelper.isAccessibilityTrusted
                        ? "trackpad.menu.no_items".localized
                        : "trackpad.error.no_permission".localized
                    return
                }
                flatItems = Self.flatten(items, depth: 0)
            }
        }
    }

    private static func flatten(_ items: [MenuItem], depth: Int) -> [FlatMenuItem] {
        var result: [FlatMenuItem] = []
        for item in items {
            if item.isSeparator || item.title.isEmpty {
                continue
            }
            if item.children.isEmpty {
                result.append(FlatMenuItem(id: item.id, item: item, depth: depth))
            } else {
                result.append(contentsOf: flatten(item.children, depth: depth + 1))
            }
        }
        return result
    }
}

// MARK: - 시스템 액션 선택

private struct TrackpadSystemActionPicker: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme

    @Binding var action: GestureAction

    private struct Group {
        let key: String
        let actions: [SystemActionType]
    }

    private let groups: [Group] = [
        Group(key: "trackpad.system.group.play", actions: [.volumeUp, .volumeDown, .mute]),
        Group(key: "trackpad.system.group.display", actions: [.lock, .displaySleep, .screenSaver, .sleep]),
        Group(key: "trackpad.system.group.mode", actions: [.darkMode]),
        Group(key: "trackpad.system.group.window", actions: [
            .minimizeFrontWindow,
            .windowLeft40, .windowLeft50, .windowLeft60,
            .windowRight40, .windowRight50, .windowRight60
        ]),
        Group(key: "trackpad.system.group.cleanup", actions: [.dockRestart, .finderRestart]),
        Group(key: "trackpad.system.group.extra", actions: [
            .screenshot, .newNote, .quickNote, .wallpaper, .wakeDisplay, .activateApp
        ])
    ]

    /// 저장만 되고 실행기는 없는 항목 — 목록에 비활성으로만 보여 준다.
    private let plannedKeys = [
        "trackpad.system.planned.focus",
        "trackpad.system.planned.prevent_sleep",
        "trackpad.system.planned.clear_recents",
        "trackpad.system.planned.airdrop",
        "trackpad.system.planned.bluetooth",
        "trackpad.system.planned.wifi"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TrackpadField("trackpad.field.system".localized, hint: "trackpad.hint.system_pick".localized) {
                Text(action.systemAction?.displayName ?? "trackpad.action.none".localized)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
                    .lineLimit(1)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(groups, id: \.key) { group in
                        Text(group.key.localized)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.tertiaryText)
                            .padding(.horizontal, 6)
                            .padding(.top, 5)
                        ForEach(group.actions) { type in
                            systemRow(type)
                        }
                    }

                    Text("trackpad.system.next_version".localized)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.tertiaryText)
                        .padding(.horizontal, 6)
                        .padding(.top, 7)
                    ForEach(plannedKeys, id: \.self) { key in
                        HStack(spacing: 6) {
                            Text(key.localized)
                                .font(.caption)
                            Spacer()
                            Text("trackpad.system.next_version_short".localized)
                                .font(.caption2)
                                .foregroundColor(theme.tertiaryText)
                        }
                        .foregroundColor(theme.tertiaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                    }
                }
                .padding(4)
            }
            .frame(height: 170)
            .background(theme.tertiaryBackground.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.bottom, 6)

            if let type = action.systemAction, type.requiresParameter {
                parameterRow(for: type)
            }
        }
    }

    private func systemRow(_ type: SystemActionType) -> some View {
        let selected = action.systemAction == type
        return Button {
            action.systemAction = type
            if !type.requiresParameter {
                action.systemText = nil
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: type.systemImage)
                    .font(.caption2)
                    .frame(width: 15)
                Text(type.displayName)
                    .font(.caption)
                Spacer(minLength: 6)
                if type.requiresParameter {
                    Text("trackpad.system.needs_parameter".localized)
                        .font(.caption2)
                        .foregroundColor(theme.tertiaryText)
                }
                if selected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .foregroundColor(theme.accentColor)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(selected ? theme.accentColor.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func parameterRow(for type: SystemActionType) -> some View {
        switch type.parameterKind {
        case .file:
            TrackpadField("trackpad.field.wallpaper".localized, hint: "trackpad.hint.wallpaper".localized) {
                HStack(spacing: 6) {
                    Text(wallpaperName)
                        .font(.caption2)
                        .foregroundColor(theme.secondaryText)
                        .lineLimit(1)
                    Button("trackpad.choose_file".localized) {
                        chooseWallpaper()
                    }
                    .controlSize(.small)
                }
            }
        case .app:
            TrackpadField("trackpad.field.app".localized, hint: "trackpad.hint.activate_app".localized) {
                Picker("", selection: Binding(
                    get: { action.systemText ?? "" },
                    set: { action.systemText = $0.isEmpty ? nil : $0 }
                )) {
                    Text("trackpad.action.none".localized).tag("")
                    ForEach(sortedApps) { app in
                        Text(app.name).tag(app.bundleID)
                    }
                }
                .labelsHidden()
                .frame(width: 230)
            }
        case .none:
            EmptyView()
        }
    }

    private var sortedApps: [AppItem] {
        store.apps
            .filter { !$0.bundleID.isEmpty }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var wallpaperName: String {
        guard let path = action.systemText, !path.isEmpty else {
            return "trackpad.action.none".localized
        }
        return FileManager.default.displayName(atPath: path)
    }

    private func chooseWallpaper() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .image]
        panel.prompt = "trackpad.choose_file".localized
        guard panel.runModal() == .OK, let url = panel.url else { return }
        action.systemText = url.path
    }
}

// MARK: - 앱 범위 선택

private struct TrackpadAppScopePicker: View {
    @Environment(\.theme) private var theme
    @Binding var selected: [String]

    @State private var apps: [AppItem] = []

    private var allApps: [AppItem] {
        var list = apps
        // 실행 중이 아닌데 이미 선택된 앱도 이름을 보여 준다
        for bundleID in selected where !list.contains(where: { $0.bundleID == bundleID }) {
            let name = ConfigStore.appName(for: bundleID) ?? bundleID
            list.append(AppItem(name: name, bundleID: bundleID, path: ""))
        }
        return list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(allApps) { app in
                    chip(app)
                }
            }
            Text("trackpad.hint.scope_apps".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        }
        .padding(.vertical, 5)
        .onAppear {
            apps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
                .compactMap { app in
                    guard let id = app.bundleIdentifier else { return nil }
                    return AppItem(name: app.localizedName ?? id, bundleID: id, path: app.bundleURL?.path ?? "")
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private func chip(_ app: AppItem) -> some View {
        let isSelected = selected.contains(app.bundleID)
        return Button {
            if isSelected {
                selected.removeAll { $0 == app.bundleID }
            } else {
                selected.append(app.bundleID)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.caption2)
                Text(app.name)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? theme.accentColor.opacity(0.16) : theme.tertiaryBackground)
            .foregroundColor(isSelected ? theme.accentColor : theme.secondaryText)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
