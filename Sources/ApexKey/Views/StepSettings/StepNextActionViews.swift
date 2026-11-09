import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// T-211 순수 로직·UI 액션 14종의 단계 설정.
///
/// "구현됨"으로 분류한 액션은 카탈로그에서 선택된다. 전용 UI가 없으면
/// 입력할 곳이 없어 "선택은 되지만 쓸 수 없는" 상태가 된다.
/// 액션마다 필요한 입력만 보여준다.
struct NextActionSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep

    private var config: TextActionConfig { TextActionConfig.decode(from: step.actionParameters) }

    private func updateConfig(_ mutate: (inout TextActionConfig) -> Void) {
        var next = config
        mutate(&next)
        step.actionParameters = try? JSONEncoder().encode(next)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(step.type.displayName)
                .font(.headline)

            controls

            if [.recognizeText, .scanQRCode, .recognizeAnimal].contains(step.type) {
                Text("ui.next_action.image_hint".localized)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            }
        }
        .sectionCard()
    }

    // MARK: - 액션별 컨트롤

    @ViewBuilder
    private var controls: some View {
        switch step.type {
        case .recognizeText, .scanQRCode, .recognizeAnimal:
            imageInput

        case .detectLanguage:
            textInput(
                label: "ui.next_action.input_text".localized,
                hint: "ui.next_action.text_hint".localized
            )

        case .measurement:
            textInput(
                label: "ui.next_action.input_text".localized,
                hint: "ui.next_action.measurement_hint".localized
            )
            unitPicker(
                label: "ui.next_action.from_unit".localized,
                selection: Binding(
                    get: { config.measurementFromUnit },
                    set: { value in updateConfig { $0.measurementFromUnit = value } }
                ),
                allowNone: true
            )
            unitPicker(
                label: "ui.next_action.to_unit".localized,
                selection: Binding<NextActions.MeasurementUnit?>(
                    get: { config.measurementUnit ?? .meters },
                    set: { value in updateConfig { $0.measurementUnit = value } }
                ),
                allowNone: false
            )

        case .adjustDate:
            textInput(
                label: "ui.next_action.date_input".localized,
                hint: "ui.next_action.date_input_hint".localized
            )
            HStack {
                Text("ui.next_action.amount".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                TextField("0", value: Binding(
                    get: { config.dateAmount ?? 0 },
                    set: { value in updateConfig { $0.dateAmount = value } }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                Picker("ui.next_action.date_unit".localized, selection: Binding(
                    get: { config.dateUnit ?? .days },
                    set: { value in updateConfig { $0.dateUnit = value } }
                )) {
                    ForEach(NextActions.DateUnit.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .labelsHidden()
            }
            formatField

        case .typeDateTime:
            formatField
            Text("ui.next_action.type_date_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)

        case .dialog:
            textInput(
                label: "ui.next_action.message".localized,
                hint: "ui.next_action.message_hint".localized
            )
            VStack(alignment: .leading, spacing: 4) {
                Text("ui.next_action.default_text".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                TextField("", text: Binding(
                    get: { config.defaultText ?? "" },
                    set: { value in updateConfig { $0.defaultText = value } }
                ))
                .textFieldStyle(.roundedBorder)
            }

        case .getConfirmation:
            textInput(
                label: "ui.next_action.message".localized,
                hint: "ui.next_action.confirm_hint".localized
            )

        case .quickLook:
            fileInput(label: "ui.next_action.file_path".localized)
            Text("ui.next_action.quicklook_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        case .preventSleep:
            Picker("ui.next_action.prevent_sleep_mode".localized, selection: Binding(
                get: { config.preventSleepMode ?? .toggle },
                set: { value in updateConfig { $0.preventSleepMode = value } }
            )) {
                ForEach(NextActions.PreventSleepMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            Text("ui.next_action.prevent_sleep_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)

        case .getDictionary:
            fileInput(label: "ui.next_action.dictionary_path".localized)
            VStack(alignment: .leading, spacing: 4) {
                Text("ui.next_action.dictionary_key".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                TextField("user.name", text: Binding(
                    get: { config.dictionaryKey ?? "" },
                    set: { value in updateConfig { $0.dictionaryKey = value } }
                ))
                .textFieldStyle(.roundedBorder)
            }

        case .listActions:
            Text("ui.next_action.list_hint".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)

        case .saveOutput:
            VStack(alignment: .leading, spacing: 4) {
                Text("ui.next_action.content".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                TextField(
                    "ui.next_action.content_hint".localized,
                    text: Binding(
                        get: { config.text ?? "" },
                        set: { value in updateConfig { $0.text = value } }
                    ),
                    axis: .vertical
                )
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
            }
            fileInput(label: "ui.next_action.save_path".localized, useSavePanel: true)
            Toggle("ui.next_action.append".localized, isOn: Binding(
                get: { config.append ?? false },
                set: { value in updateConfig { $0.append = value } }
            ))

        default:
            EmptyView()
        }
    }

    // MARK: - 공통 입력

    private func textInput(label: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField(hint, text: Binding(
                get: { config.text?.isEmpty == false ? config.text! : step.target },
                set: { value in
                    if config.text?.isEmpty == false {
                        updateConfig { $0.text = value }
                    } else {
                        step.target = value
                    }
                }
            ))
            .textFieldStyle(.roundedBorder)
            Text(hint)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        }
    }

    private var imageInput: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ui.next_action.image_source".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            HStack {
                TextField(
                    "ui.next_action.image_hint".localized,
                    text: Binding(
                        get: { config.text?.isEmpty == false ? config.text! : step.target },
                        set: { value in
                            if config.text?.isEmpty == false {
                                updateConfig { $0.text = value }
                            } else {
                                step.target = value
                            }
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)
                Button("ui.browse".localized) { chooseImage() }
            }
        }
    }

    private func fileInput(label: String, useSavePanel: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            HStack {
                TextField(label, text: Binding(
                    get: {
                        useSavePanel
                            ? (config.savePath?.isEmpty == false ? config.savePath! : step.target)
                            : step.target
                    },
                    set: { value in
                        if useSavePanel {
                            updateConfig { $0.savePath = value }
                        } else {
                            step.target = value
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)
                Button("ui.browse".localized) {
                    if useSavePanel { chooseSavePath() } else { chooseFile() }
                }
            }
        }
    }

    private var formatField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ui.text_action.date_format".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("yyyy-MM-dd HH:mm", text: Binding(
                get: { config.dateFormat ?? "" },
                set: { value in updateConfig { $0.dateFormat = value } }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }

    private func unitPicker(
        label: String,
        selection: Binding<NextActions.MeasurementUnit?>,
        allowNone: Bool
    ) -> some View {
        Picker(label, selection: selection) {
            if allowNone {
                Text("ui.next_action.unit_auto".localized).tag(NextActions.MeasurementUnit?.none)
            }
            ForEach(NextActions.MeasurementUnit.allCases, id: \.self) { unit in
                Text(unit.symbol).tag(NextActions.MeasurementUnit?.some(unit))
            }
        }
    }
    // MARK: - 파일 선택

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK, let url = panel.url {
            updateConfig { $0.text = url.path }
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            updateConfig { $0.savePath = url.path }
        }
    }

    private func chooseSavePath() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "output.txt"
        if panel.runModal() == .OK, let url = panel.url {
            updateConfig { $0.savePath = url.path }
        }
    }
}
