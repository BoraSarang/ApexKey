import SwiftUI

/// T-214 Apple 앱 1 — Notes·Reminders·Calendar 단계 설정.
///
/// 날짜는 절대 시각이 아니라 "지금부터 몇 분"으로 받는다. 로케일에 따라 해석이
/// 달라지는 문자열을 AppleScript에 넘기지 않기 위해서다.
struct AppleAppSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep

    private var config: AppleAppConfig { AppleAppConfig.decode(from: step.actionParameters) }

    private func updateConfig(_ mutate: (inout AppleAppConfig) -> Void) {
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
        case .createNote:
            titleField
            bodyField(hint: "apple.body_hint".localized)

        case .noteActions:
            Picker("apple.note_operation".localized, selection: Binding(
                get: { config.resolvedNoteOperation },
                set: { value in updateConfig { $0.noteOperation = value } }
            )) {
                ForEach(AppleAppConfig.NoteOperation.allCases, id: \.self) { operation in
                    Text(operation.displayName).tag(operation)
                }
            }
            if config.resolvedNoteOperation == .createFolder {
                field(
                    "apple.folder_name".localized,
                    hint: "apple.folder_name_hint".localized,
                    text: Binding(
                        get: { config.folderName ?? "" },
                        set: { value in updateConfig { $0.folderName = value.isEmpty ? nil : value } }
                    )
                )
            } else {
                titleField
                if config.resolvedNoteOperation == .append {
                    bodyField(hint: "apple.append_hint".localized)
                }
            }

        case .reminders:
            Picker("apple.reminder_operation".localized, selection: Binding(
                get: { config.resolvedReminderOperation },
                set: { value in updateConfig { $0.reminderOperation = value } }
            )) {
                ForEach(AppleAppConfig.ReminderOperation.allCases, id: \.self) { operation in
                    Text(operation.displayName).tag(operation)
                }
            }
            if config.resolvedReminderOperation == .add {
                titleField
                field(
                    "apple.list_name".localized,
                    hint: "apple.list_name_hint".localized,
                    text: Binding(
                        get: { config.listName ?? "" },
                        set: { value in updateConfig { $0.listName = value.isEmpty ? nil : value } }
                    )
                )
                bodyField(hint: "apple.reminder_notes_hint".localized)
                dueOffsetField
            }

        case .calendar:
            Picker("apple.calendar_operation".localized, selection: Binding(
                get: { config.resolvedCalendarOperation },
                set: { value in updateConfig { $0.calendarOperation = value } }
            )) {
                ForEach(AppleAppConfig.CalendarOperation.allCases, id: \.self) { operation in
                    Text(operation.displayName).tag(operation)
                }
            }
            if config.resolvedCalendarOperation == .addEvent {
                titleField
                field(
                    "apple.calendar_name".localized,
                    hint: "apple.calendar_name_hint".localized,
                    text: Binding(
                        get: { config.calendarName ?? "" },
                        set: { value in updateConfig { $0.calendarName = value.isEmpty ? nil : value } }
                    )
                )
                HStack(spacing: 12) {
                    numberField(
                        "apple.start_offset".localized,
                        value: Binding(
                            get: { config.resolvedStartOffset },
                            set: { value in updateConfig { $0.startOffsetMinutes = value } }
                        )
                    )
                    numberField(
                        "apple.duration".localized,
                        value: Binding(
                            get: { config.resolvedDuration },
                            set: { value in updateConfig { $0.durationMinutes = value } }
                        )
                    )
                }
                field(
                    "apple.location".localized,
                    hint: "apple.location_hint".localized,
                    text: Binding(
                        get: { config.location ?? "" },
                        set: { value in updateConfig { $0.location = value.isEmpty ? nil : value } }
                    )
                )
                bodyField(hint: "apple.event_notes_hint".localized)
            }

        default:
            EmptyView()
        }
    }

    // MARK: - 공통 필드

    private var titleField: some View {
        field(
            "apple.title".localized,
            hint: "apple.title_hint".localized,
            text: Binding(
                get: { config.title ?? "" },
                set: { value in updateConfig { $0.title = value.isEmpty ? nil : value } }
            )
        )
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

    private func field(_ label: String, hint: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField(hint, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func numberField(_ label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField(label, value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
        }
    }

    private var dueOffsetField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("apple.has_due_date".localized, isOn: Binding(
                get: { config.dueOffsetMinutes != nil },
                set: { value in updateConfig { $0.dueOffsetMinutes = value ? 60 : nil } }
            ))
            if config.dueOffsetMinutes != nil {
                numberField(
                    "apple.due_offset".localized,
                    value: Binding(
                        get: { config.dueOffsetMinutes ?? 60 },
                        set: { value in updateConfig { $0.dueOffsetMinutes = value } }
                    )
                )
                Text("apple.due_offset_hint".localized)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            }
        }
    }
}
