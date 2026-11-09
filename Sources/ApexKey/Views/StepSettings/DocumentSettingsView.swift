import AppKit
import SwiftUI

/// T-216 문서 앱 — Pages·Numbers·TextEdit 단계 설정.
///
/// 본문 편집과 글꼴 지정은 TextEdit 전용이라는 점을 힌트로 알린다.
/// Pages·Numbers가 설치되어 있지 않으면 실행 시 "앱 미설치" 사유가 나온다.
struct DocumentSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep

    private var config: DocumentConfig { DocumentConfig.decode(from: step.actionParameters) }

    private func updateConfig(_ mutate: (inout DocumentConfig) -> Void) {
        var next = config
        mutate(&next)
        step.actionParameters = next.encode()
    }

    private var appChoices: [DocumentConfig.App] {
        step.type == .viewDocument
            ? DocumentConfig.App.allCases
            : DocumentConfig.App.allCases.filter { $0 != .defaultApp }
    }

    private var selectedApp: DocumentConfig.App {
        config.app ?? (step.type == .viewDocument ? .defaultApp : .textEdit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(step.type.displayName)
                .font(.headline)

            controls

            Text("apple.automation_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        }
        .sectionCard()
    }

    @ViewBuilder
    private var controls: some View {
        Picker("doc.app".localized, selection: Binding(
            get: { selectedApp },
            set: { value in updateConfig { $0.app = value } }
        )) {
            ForEach(appChoices, id: \.self) { app in
                Text(app.displayName).tag(app)
            }
        }

        switch step.type {
        case .newDocument:
            contentField(hint: "doc.content_hint".localized)
            Text("doc.new_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)

        case .viewDocument:
            pathField
            Text("doc.view_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)

        case .editDocument:
            pathField
            contentField(hint: "doc.content_previous_hint".localized)
            Picker("doc.edit_mode".localized, selection: Binding(
                get: { config.resolvedEditMode },
                set: { value in updateConfig { $0.editMode = value } }
            )) {
                ForEach(DocumentConfig.EditMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            Text("doc.unsupported_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)

        case .setParagraphStyle:
            pathField
            HStack(spacing: 12) {
                textField(
                    "doc.font".localized,
                    hint: "doc.font_hint".localized,
                    value: Binding(
                        get: { config.fontName ?? "" },
                        set: { value in updateConfig { $0.fontName = value.isEmpty ? nil : value } }
                    )
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text("doc.font_size".localized)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                    TextField("13", value: Binding(
                        get: { config.fontSize ?? 0 },
                        set: { value in updateConfig { $0.fontSize = value } }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                }
            }
            Text("doc.style_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)

        default:
            EmptyView()
        }
    }

    private func contentField(hint: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("doc.content".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField(hint, text: Binding(
                get: { config.content ?? "" },
                set: { value in updateConfig { $0.content = value.isEmpty ? nil : value } }
            ), axis: .vertical)
            .lineLimit(2...6)
            .textFieldStyle(.roundedBorder)
        }
    }

    private var pathField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("doc.path".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            HStack {
                TextField("doc.path_hint".localized, text: Binding(
                    get: { config.path ?? "" },
                    set: { value in updateConfig { $0.path = value.isEmpty ? nil : value } }
                ))
                .textFieldStyle(.roundedBorder)
                Button("ui.browse".localized) { chooseDocument() }
            }
            Text("doc.path_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        }
    }

    private func textField(_ label: String, hint: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField(hint, text: value)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func chooseDocument() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            updateConfig { $0.path = url.path }
        }
    }
}
