import AppKit
import SwiftUI

/// T-215 Apple 앱 2 — Mail·Music·Podcasts·Photos 단계 설정.
///
/// 메일 발송 스위치는 경고 문구와 함께 둔다. 초안만 여는 것이 기본이고,
/// 자동화에서 실수로 메일이 나가는 것이 가장 큰 위험이기 때문이다.
struct AppleMediaSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep

    private var config: AppleMediaConfig { AppleMediaConfig.decode(from: step.actionParameters) }

    private func updateConfig(_ mutate: (inout AppleMediaConfig) -> Void) {
        var next = config
        mutate(&next)
        step.actionParameters = next.encode()
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
        switch step.type {
        case .mail, .emailData:
            recipientFields
            textField(
                "media.mail.subject".localized,
                hint: "apple.title_hint".localized,
                value: Binding(
                    get: { config.subject ?? "" },
                    set: { value in updateConfig { $0.subject = value.isEmpty ? nil : value } }
                )
            )
            bodyField(hint: step.type == .emailData
                ? "media.email_data.hint".localized
                : "apple.body_hint".localized)
            attachmentField(hint: step.type == .emailData
                ? "media.mail.attachments_previous_hint".localized
                : "media.mail.attachments_hint".localized)
            Toggle("media.mail.send".localized, isOn: Binding(
                get: { config.shouldSend },
                set: { value in updateConfig { $0.sendImmediately = value } }
            ))
            if config.shouldSend {
                Text("media.mail.send_hint".localized)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            }

        case .setMailBody:
            bodyField(hint: "media.mail.body_hint".localized)

        case .setMailRecipients:
            recipientFields

        case .playMusic:
            textField(
                "media.music.query".localized,
                hint: "media.music.query_hint".localized,
                value: Binding(
                    get: { config.query ?? "" },
                    set: { value in updateConfig { $0.query = value.isEmpty ? nil : value } }
                )
            )
            textField(
                "media.music.playlist".localized,
                hint: "media.music.playlist_hint".localized,
                value: Binding(
                    get: { config.playlistName ?? "" },
                    set: { value in updateConfig { $0.playlistName = value.isEmpty ? nil : value } }
                )
            )

        case .playPodcast:
            textField(
                "media.podcast.url".localized,
                hint: "media.podcast.url_hint".localized,
                value: Binding(
                    get: { config.podcastURL ?? "" },
                    set: { value in updateConfig { $0.podcastURL = value.isEmpty ? nil : value } }
                )
            )
            Text("media.podcast.hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)

        case .podcasts:
            Text("media.podcast.open_hint".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)

        case .photos:
            countField
            Text("media.photos.list_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)

        case .getLastPhoto:
            countField
            destinationField
            Text("media.photos.export_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)

        case .viewPhotos:
            textField(
                "media.photos.album".localized,
                hint: "media.photos.album_hint".localized,
                value: Binding(
                    get: { config.albumName ?? "" },
                    set: { value in updateConfig { $0.albumName = value.isEmpty ? nil : value } }
                )
            )

        case .randomPhoto:
            Text("media.photos.random_hint".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)

        case .album:
            Picker("media.album.operation".localized, selection: Binding(
                get: { config.resolvedAlbumOperation },
                set: { value in updateConfig { $0.albumOperation = value } }
            )) {
                ForEach(AppleMediaConfig.AlbumOperation.allCases, id: \.self) { operation in
                    Text(operation.displayName).tag(operation)
                }
            }
            if config.resolvedAlbumOperation == .create {
                textField(
                    "media.album.name".localized,
                    hint: "media.album.name_hint".localized,
                    value: Binding(
                        get: { config.albumName ?? "" },
                        set: { value in updateConfig { $0.albumName = value.isEmpty ? nil : value } }
                    )
                )
            }

        default:
            EmptyView()
        }
    }

    // MARK: - 필드

    private var recipientFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            textField(
                "media.mail.to".localized,
                hint: "media.mail.recipients_hint".localized,
                value: Binding(
                    get: { config.to ?? "" },
                    set: { value in updateConfig { $0.to = value.isEmpty ? nil : value } }
                )
            )
            textField(
                "media.mail.cc".localized,
                hint: "media.mail.recipients_hint".localized,
                value: Binding(
                    get: { config.cc ?? "" },
                    set: { value in updateConfig { $0.cc = value.isEmpty ? nil : value } }
                )
            )
            textField(
                "media.mail.bcc".localized,
                hint: "media.mail.recipients_hint".localized,
                value: Binding(
                    get: { config.bcc ?? "" },
                    set: { value in updateConfig { $0.bcc = value.isEmpty ? nil : value } }
                )
            )
        }
    }

    private func bodyField(hint: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("apple.body".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField(hint, text: Binding(
                get: { config.body ?? "" },
                set: { value in updateConfig { $0.body = value.isEmpty ? nil : value } }
            ), axis: .vertical)
            .lineLimit(2...6)
            .textFieldStyle(.roundedBorder)
        }
    }

    private func attachmentField(hint: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("media.mail.attachments".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            HStack(alignment: .top) {
                TextField(hint, text: Binding(
                    get: { config.attachments ?? "" },
                    set: { value in updateConfig { $0.attachments = value.isEmpty ? nil : value } }
                ), axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                Button("ui.browse".localized) { chooseAttachments() }
            }
            Text(hint)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        }
    }

    private var countField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("media.photos.count".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("1", value: Binding(
                get: { config.resolvedPhotoCount },
                set: { value in updateConfig { $0.photoCount = value } }
            ), format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 100)
        }
    }

    private var destinationField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("media.photos.destination".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            HStack {
                TextField("media.photos.destination_hint".localized, text: Binding(
                    get: { config.destination ?? "" },
                    set: { value in updateConfig { $0.destination = value.isEmpty ? nil : value } }
                ))
                .textFieldStyle(.roundedBorder)
                Button("ui.browse".localized) { chooseDestination() }
            }
            Text("media.photos.destination_hint".localized)
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

    // MARK: - 파일 선택

    private func chooseAttachments() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK, !panel.urls.isEmpty {
            updateConfig { $0.attachments = panel.urls.map(\.path).joined(separator: "\n") }
        }
    }

    private func chooseDestination() {
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
