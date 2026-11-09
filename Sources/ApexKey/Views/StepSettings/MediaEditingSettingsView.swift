import AppKit
import SwiftUI

/// T-220 미디어 편집·캡처 단계 설정.
struct MediaEditingSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep

    private var config: MediaEditingConfig {
        MediaEditingConfig.decode(from: step.actionParameters)
    }

    private func updateConfig(_ mutate: (inout MediaEditingConfig) -> Void) {
        var next = config
        mutate(&next)
        step.actionParameters = next.encode()
    }

    private var usesFile: Bool {
        [.rotateImage, .cropImage, .trimVideo].contains(step.type)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(step.type.displayName)
                .font(.headline)

            controls

            Text("media.original_preserved".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        }
        .sectionCard()
    }

    @ViewBuilder
    private var controls: some View {
        switch step.type {
        case .rotateImage:
            fileField(title: "media.path".localized, value: config.path ?? "", isDirectory: false) { value in
                updateConfig { $0.path = value }
            }
            outputField
            labeledField(title: "media.angle".localized, hint: "media.angle_hint".localized, value: numberText(config.resolvedAngle)) { value in
                updateConfig { $0.angle = Double(value) }
            }

        case .cropImage:
            fileField(title: "media.path".localized, value: config.path ?? "", isDirectory: false) { value in
                updateConfig { $0.path = value }
            }
            outputField
            HStack(spacing: 10) {
                numberField("media.crop_x".localized, value: config.cropX ?? 0) { value in
                    updateConfig { $0.cropX = value }
                }
                numberField("media.crop_y".localized, value: config.cropY ?? 0) { value in
                    updateConfig { $0.cropY = value }
                }
            }
            HStack(spacing: 10) {
                numberField("media.crop_width".localized, value: config.cropWidth ?? 0) { value in
                    updateConfig { $0.cropWidth = value }
                }
                numberField("media.crop_height".localized, value: config.cropHeight ?? 0) { value in
                    updateConfig { $0.cropHeight = value }
                }
            }
            Text("media.crop_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)

        case .trimVideo:
            fileField(title: "media.path".localized, value: config.path ?? "", isDirectory: false) { value in
                updateConfig { $0.path = value }
            }
            outputField
            HStack(spacing: 10) {
                numberField("media.start".localized, value: config.resolvedStart) { value in
                    updateConfig { $0.startSeconds = value }
                }
                numberField("media.end".localized, value: config.resolvedEnd) { value in
                    updateConfig { $0.endSeconds = value }
                }
            }
            Text("media.trim_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)

        case .camera:
            fileField(title: "media.camera_output".localized, value: config.outputPath ?? "", isDirectory: true) { value in
                updateConfig { $0.outputPath = value }
            }
            Text("media.camera_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)

        case .setVolumeMedia:
            HStack {
                Slider(value: Binding(
                    get: { Double(config.resolvedVolume) },
                    set: { value in updateConfig { $0.volume = Int(value.rounded()) } }
                ), in: 0...100)
                Text("\(config.resolvedVolume)%")
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }

        case .moveMedia:
            fileField(title: "media.destination".localized, value: config.destination ?? "", isDirectory: true) { value in
                updateConfig { $0.destination = value }
            }
            Toggle("media.confirm_move".localized, isOn: Binding(
                get: { config.resolvedConfirm },
                set: { value in updateConfig { $0.confirmBeforeChange = value } }
            ))
            .toggleStyle(.checkbox)

        case .musicAndVideo:
            Picker("media.playback".localized, selection: Binding(
                get: { config.resolvedPlayback },
                set: { value in updateConfig { $0.playback = value } }
            )) {
                ForEach(MediaEditingConfig.PlaybackCommand.allCases, id: \.self) { command in
                    Text(command.displayName).tag(command)
                }
            }
            .pickerStyle(.menu)

        default:
            EmptyView()
        }
    }

    private var outputField: some View {
        fileField(
            title: "media.output".localized,
            value: config.outputPath ?? "",
            isDirectory: false
        ) { value in
            updateConfig { $0.outputPath = value }
        }
    }

    private func numberText(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    private func labeledField(
        title: String,
        hint: String,
        value: String,
        onChange: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField(hint, text: Binding(get: { value }, set: onChange))
                .textFieldStyle(.roundedBorder)
        }
    }

    private func numberField(
        _ title: String,
        value: Double,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("0", text: Binding(
                get: { numberText(value) },
                set: { onChange(Double($0) ?? 0) }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }

    private func fileField(
        title: String,
        value: String,
        isDirectory: Bool,
        onChange: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            HStack {
                TextField("media.path_hint".localized, text: Binding(get: { value }, set: onChange))
                    .textFieldStyle(.roundedBorder)
                Button("ui.browse".localized) {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = !isDirectory
                    panel.canChooseDirectories = isDirectory
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
