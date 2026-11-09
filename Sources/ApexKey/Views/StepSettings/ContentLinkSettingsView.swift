import AppKit
import SwiftUI

/// T-221 콘텐츠·위치·웹 — 메시지·이메일·지도·대중교통·웹·프레젠테이션·아이콘 설정.
struct ContentLinkSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep

    private var config: ContentLinkConfig {
        ContentLinkConfig.decode(from: step.actionParameters)
    }

    private func updateConfig(_ mutate: (inout ContentLinkConfig) -> Void) {
        var next = config
        mutate(&next)
        step.actionParameters = next.encode()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(step.type.displayName)
                .font(.headline)

            controls

            hint
        }
        .sectionCard()
    }

    @ViewBuilder
    private var controls: some View {
        switch step.type {
        case .message:
            textField("content.recipients".localized, value: config.recipients ?? "", multiline: false) { value in
                updateConfig { $0.recipients = value }
            }
            textField("content.body".localized, value: config.body ?? "", multiline: true) { value in
                updateConfig { $0.body = value }
            }
            Toggle("content.preview_before_send".localized, isOn: Binding(
                get: { config.resolvedPreview },
                set: { value in updateConfig { $0.preview = value } }
            ))
            .toggleStyle(.checkbox)

        case .email:
            textField("content.recipients".localized, value: config.recipients ?? "", multiline: false) { value in
                updateConfig { $0.recipients = value }
            }
            textField("content.subject".localized, value: config.subject ?? "", multiline: false) { value in
                updateConfig { $0.subject = value }
            }
            textField("content.body".localized, value: config.body ?? "", multiline: true) { value in
                updateConfig { $0.body = value }
            }
            Toggle("content.send_immediately".localized, isOn: Binding(
                get: { config.resolvedSend },
                set: { value in updateConfig { $0.sendImmediately = value } }
            ))
            .toggleStyle(.checkbox)

        case .map, .transportation:
            textField("content.origin".localized, value: config.origin ?? "", multiline: false) { value in
                updateConfig { $0.origin = value }
            }
            textField("content.destination".localized, value: config.destination ?? "", multiline: false) { value in
                updateConfig { $0.destination = value }
            }
            if step.type == .map {
                Picker("content.travel_mode".localized, selection: Binding(
                    get: { config.resolvedTravelMode },
                    set: { value in updateConfig { $0.travelMode = value } }
                )) {
                    ForEach(ContentLinkConfig.TravelMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            }

        case .webContent:
            textField("content.url".localized, value: config.url ?? "", multiline: false) { value in
                updateConfig { $0.url = value }
            }
            Picker("content.mode".localized, selection: Binding(
                get: { config.resolvedWebContentMode },
                set: { value in updateConfig { $0.webContentMode = value } }
            )) {
                ForEach(ContentLinkConfig.WebContentMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.menu)

        case .webIntegration:
            Picker("content.web_action".localized, selection: Binding(
                get: { config.resolvedWebAction },
                set: { value in updateConfig { $0.webAction = value } }
            )) {
                ForEach(ContentLinkConfig.WebAction.allCases, id: \.self) { action in
                    Text(action.displayName).tag(action)
                }
            }
            .pickerStyle(.menu)

            textField(
                (config.resolvedWebAction == .fetch ? "content.url" : "content.input").localized,
                value: (config.resolvedWebAction == .fetch ? config.url ?? "" : config.body ?? ""),
                multiline: config.resolvedWebAction != .fetch
            ) { value in
                updateConfig { next in
                    if next.resolvedWebAction == .fetch {
                        next.url = value
                    } else {
                        next.body = value
                    }
                }
            }

        case .presentation:
            Picker("content.presentation_action".localized, selection: Binding(
                get: { config.resolvedPresentationAction },
                set: { value in updateConfig { $0.presentationAction = value } }
            )) {
                ForEach(ContentLinkConfig.PresentationAction.allCases, id: \.self) { action in
                    Text(action.displayName).tag(action)
                }
            }
            .pickerStyle(.menu)

        case .createShortcutIcon:
            textField("content.symbol".localized, value: config.resolvedSymbol, multiline: false) { value in
                updateConfig { $0.symbolName = value }
            }
            HStack(spacing: 8) {
                Text("content.color".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                TextField("#0A84FF", text: Binding(
                    get: { config.resolvedColorHex },
                    set: { value in updateConfig { $0.colorHex = value } }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 110)
            }
            pathField(title: "content.output".localized) { value in
                updateConfig { $0.outputPath = value }
            }

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var hint: some View {
        switch step.type {
        case .message:
            Text("content.message_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        case .email:
            Text("content.email_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        case .map, .transportation:
            Text("content.map_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        case .webContent, .webIntegration:
            Text("content.web_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        case .presentation:
            Text("content.presentation_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        case .createShortcutIcon:
            Text("content.icon_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        default:
            EmptyView()
        }
    }

    private func textField(
        _ title: String,
        value: String,
        multiline: Bool,
        onChange: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            if multiline {
                GrowingTextEditor(text: Binding(get: { value }, set: onChange))
                    .frame(minHeight: 64)
            } else {
                TextField("content.value_hint".localized, text: Binding(get: { value }, set: onChange))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func pathField(title: String, onChange: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            HStack {
                TextField("content.value_hint".localized, text: Binding(
                    get: { config.outputPath ?? "" },
                    set: onChange
                ))
                .textFieldStyle(.roundedBorder)
                Button("ui.browse".localized) {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.canCreateDirectories = true
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        onChange(url.path)
                    }
                }
                .controlSize(.small)
            }
        }
    }
}
