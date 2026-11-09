import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// T-213 파일 액션 7종의 단계 설정.
///
/// 데이터를 바꾸는 동작은 **확인 기본값이 켜져 있다.** 사용자가 자동화에서
/// 확인 없이 돌리고 싶을 때만 해제한다. 소스 경로를 비우면 이전 단계 출력에서
/// 파일 목록을 받는다는 점을 힌트로 알린다.
struct FileActionSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep

    private var config: FileActionConfig { FileActionConfig.decode(from: step.actionParameters) }

    private func updateConfig(_ mutate: (inout FileActionConfig) -> Void) {
        var next = config
        mutate(&next)
        step.actionParameters = next.encode()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(step.type.displayName)
                .font(.headline)

            controls

            if showsConfirmToggle {
                Toggle("file.confirm_before_change".localized, isOn: Binding(
                    get: { config.confirmBeforeChange ?? true },
                    set: { value in updateConfig { $0.confirmBeforeChange = value } }
                ))
                Text("file.confirm_before_change_hint".localized)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            }
        }
        .sectionCard()
    }

    private var showsConfirmToggle: Bool {
        switch step.type {
        case .moveFiles, .renameFiles, .externalStorage:
            return true
        case .fileActions:
            return (config.operation ?? .copy).changesData
        default:
            return false
        }
    }

    // MARK: - 액션별 컨트롤

    @ViewBuilder
    private var controls: some View {
        switch step.type {
        case .getFiles:
            sourceField(
                label: "file.source_folder".localized,
                hint: "file.source_folder_hint".localized,
                chooseFolders: true
            )
            Toggle("file.recursive".localized, isOn: Binding(
                get: { config.recursive ?? false },
                set: { value in updateConfig { $0.recursive = value } }
            ))
            Toggle("file.include_hidden".localized, isOn: Binding(
                get: { config.includeHidden ?? false },
                set: { value in updateConfig { $0.includeHidden = value } }
            ))
            labeledField(
                "file.extensions".localized,
                hint: "file.extensions_hint".localized,
                text: Binding(
                    get: { config.extensions ?? "" },
                    set: { value in updateConfig { $0.extensions = value.isEmpty ? nil : value } }
                )
            )

        case .moveFiles:
            sourceField(
                label: "file.source_files".localized,
                hint: "file.source_files_hint".localized,
                chooseFolders: false
            )
            destinationField(label: "file.destination_folder".localized)
            overwriteToggle

        case .renameFiles:
            sourceField(
                label: "file.source_files".localized,
                hint: "file.source_files_hint".localized,
                chooseFolders: false
            )
            labeledField(
                "file.rename_template".localized,
                hint: "file.rename_template_hint".localized,
                text: Binding(
                    get: { config.template ?? "" },
                    set: { value in updateConfig { $0.template = value.isEmpty ? nil : value } }
                )
            )
            HStack(spacing: 8) {
                labeledField(
                    "file.find_text".localized,
                    hint: "file.find_text_hint".localized,
                    text: Binding(
                        get: { config.findText ?? "" },
                        set: { value in updateConfig { $0.findText = value.isEmpty ? nil : value } }
                    )
                )
                labeledField(
                    "file.replace_text".localized,
                    hint: "file.replace_text_hint".localized,
                    text: Binding(
                        get: { config.replaceText ?? "" },
                        set: { value in updateConfig { $0.replaceText = value.isEmpty ? nil : value } }
                    )
                )
            }
            HStack {
                Text("file.start_number".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                TextField("1", value: Binding(
                    get: { config.startNumber ?? 1 },
                    set: { value in updateConfig { $0.startNumber = value } }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
            }
            overwriteToggle

        case .extractArchive:
            sourceField(
                label: "file.archive_path".localized,
                hint: "file.archive_path_hint".localized,
                chooseFolders: false
            )
            destinationField(
                label: "file.extract_destination".localized,
                hint: "file.extract_destination_hint".localized
            )

        case .externalStorage:
            Picker("file.storage_mode".localized, selection: Binding(
                get: { config.storageMode ?? .list },
                set: { value in updateConfig { $0.storageMode = value } }
            )) {
                ForEach(FileActionConfig.StorageMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            if (config.storageMode ?? .list) == .copy {
                sourceField(
                    label: "file.source_files".localized,
                    hint: "file.source_files_hint".localized,
                    chooseFolders: false
                )
                volumeField
                labeledField(
                    "file.volume_subpath".localized,
                    hint: "file.volume_subpath_hint".localized,
                    text: Binding(
                        get: { config.destination ?? "" },
                        set: { value in updateConfig { $0.destination = value.isEmpty ? nil : value } }
                    )
                )
                overwriteToggle
            } else {
                Text("file.storage_list_hint".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }

        case .fileActions:
            Picker("file.operation".localized, selection: Binding(
                get: { config.operation ?? .copy },
                set: { value in updateConfig { $0.operation = value } }
            )) {
                ForEach(FileActionConfig.Operation.allCases, id: \.self) { operation in
                    Text(operation.displayName).tag(operation)
                }
            }
            sourceField(
                label: "file.source_files".localized,
                hint: "file.source_files_hint".localized,
                chooseFolders: false
            )
            if [.copy, .move].contains(config.operation ?? .copy) {
                destinationField(label: "file.destination_folder".localized)
                overwriteToggle
            }
            if (config.operation ?? .copy) == .trash {
                Text("file.trash_hint".localized)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            }

        case .getAttachment:
            destinationField(
                label: "file.attachment_folder".localized,
                hint: "file.attachment_folder_hint".localized
            )
            Text("file.attachment_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)

        default:
            EmptyView()
        }
    }

    // MARK: - 공통 컨트롤

    private var overwriteToggle: some View {
        Toggle("file.overwrite".localized, isOn: Binding(
            get: { config.overwrite ?? false },
            set: { value in updateConfig { $0.overwrite = value } }
        ))
    }

    private var volumeField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("file.volume".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            let volumes = FileActions.externalVolumes()
            if volumes.isEmpty {
                TextField("file.volume_hint".localized, text: Binding(
                    get: { config.volumeName ?? "" },
                    set: { value in updateConfig { $0.volumeName = value.isEmpty ? nil : value } }
                ))
                .textFieldStyle(.roundedBorder)
            } else {
                Picker("file.volume".localized, selection: Binding(
                    get: { config.volumeName ?? "" },
                    set: { value in updateConfig { $0.volumeName = value.isEmpty ? nil : value } }
                )) {
                    Text("file.volume_auto".localized).tag("")
                    ForEach(volumes, id: \.self) { volume in
                        Text(volume.lastPathComponent).tag(volume.lastPathComponent)
                    }
                }
                .labelsHidden()
            }
        }
    }

    private func sourceField(label: String, hint: String, chooseFolders: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            HStack(alignment: .top) {
                TextField(
                    hint,
                    text: Binding(
                        get: { config.sourcePaths ?? "" },
                        set: { value in updateConfig { $0.sourcePaths = value.isEmpty ? nil : value } }
                    ),
                    axis: .vertical
                )
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                Button("ui.browse".localized) {
                    if chooseFolders { chooseFolderForSource() } else { chooseFilesForSource() }
                }
            }
            Text(hint)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        }
    }

    private func destinationField(label: String, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            HStack {
                TextField(hint ?? label, text: Binding(
                    get: { config.destination ?? "" },
                    set: { value in updateConfig { $0.destination = value.isEmpty ? nil : value } }
                ))
                .textFieldStyle(.roundedBorder)
                Button("ui.browse".localized) { chooseDestinationFolder() }
            }
            if let hint {
                Text(hint)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            }
        }
    }

    private func labeledField(_ label: String, hint: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField(hint, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - 파일 선택

    private func chooseFolderForSource() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            updateConfig { $0.sourcePaths = url.path }
        }
    }

    private func chooseFilesForSource() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            let paths = panel.urls.map(\.path)
            if !paths.isEmpty {
                updateConfig { $0.sourcePaths = paths.joined(separator: "\n") }
            }
        }
    }

    private func chooseDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            updateConfig { $0.destination = url.path }
        }
    }
}
