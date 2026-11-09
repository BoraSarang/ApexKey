import AppKit
import SwiftUI

/// 단축어 자동화(트리거) 설정 화면
struct AutomationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Binding var automations: [AutomationTrigger]
    
    @State private var newTriggerType: TriggerCategory = .time
    
    /// 감시자가 설치되는 카테고리만 노출한다. 지원하지 않는 트리거
    /// (와이파이·블루투스·집중모드·스테이지매니저)는 숨긴다.
    /// "쓸모있는 몇 개"만 보인다 (사용자 결정).
    private let categories: [TriggerCategory] = [.time, .filesystem, .hardware, .power, .system]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더
            HStack {
                Label("ui.automation.personal".localized, systemImage: "bolt.badge.clock")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button("ui.done".localized) { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(16)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 기존 트리거 목록
                    if automations.isEmpty {
                        Text("ui.automation.no_triggers".localized)
                            .font(.callout)
                            .foregroundColor(theme.secondaryText)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(Array(automations.enumerated()), id: \.element.id) { index, trigger in
                            triggerRow(trigger, at: index)
                        }
                    }
                    
                    Divider()
                    
                    // 새 트리거 추가
                    addSection
                }
                .padding(16)
            }
        }
        .frame(width: 480, height: 560)
        .background(theme.primaryBackground)
    }
    
    // MARK: - 트리거 행
    
    @ViewBuilder
    private func triggerRow(_ trigger: AutomationTrigger, at index: Int) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color(for: trigger).opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: trigger.systemImage)
                    .font(.system(size: 14))
                    .foregroundColor(color(for: trigger))
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(trigger.displayName)
                    .font(.callout)
                    .fontWeight(.medium)
                Text(trigger.category.displayName + " · " + trigger.minimumOSVersion)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
                if !trigger.isWatcherSupported {
                    Text("ui.automation.soon".localized)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                if case .timeOfDay = trigger {
                    timeRepeatEditor(for: trigger)
                }
                triggerDetailEditor(for: trigger)
            }

            Spacer()

            Button(role: .destructive) {
                automations.remove(at: index)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .background(theme.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// 시간 트리거 반복 규칙 편집 (weekly/monthly/custom 기준 요일·날짜) (P1)
    @ViewBuilder
    private func timeRepeatEditor(for trigger: AutomationTrigger) -> some View {
        if case .timeOfDay(var timeTrigger) = trigger {
            let index = automations.firstIndex(where: { $0.id == trigger.id })
            VStack(alignment: .leading, spacing: 6) {
                Picker("repeat.rule".localized, selection: Binding(
                    get: { timeTrigger.repeatRule },
                    set: { newValue in
                        guard let index else { return }
                        timeTrigger.repeatRule = newValue
                        if newValue == .weekly, timeTrigger.weeklyWeekday == nil {
                            timeTrigger.weeklyWeekday = Calendar.current.component(.weekday, from: Date())
                        }
                        if newValue == .monthly, timeTrigger.monthlyDay == nil {
                            timeTrigger.monthlyDay = Calendar.current.component(.day, from: Date())
                        }
                        if newValue == .custom, timeTrigger.customWeekdays == nil || timeTrigger.customWeekdays?.isEmpty == true {
                            timeTrigger.customWeekdays = [Calendar.current.component(.weekday, from: Date())]
                        }
                        automations[index] = .timeOfDay(timeTrigger)
                    }
                )) {
                    ForEach(RepeatRule.allCases) { rule in
                        Text(rule.displayName).tag(rule)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)

                switch timeTrigger.repeatRule {
                case .weekly:
                    Picker("ui.automation.weekday".localized, selection: Binding(
                        get: { timeTrigger.weeklyWeekday ?? Calendar.current.component(.weekday, from: Date()) },
                        set: { day in
                            guard let index else { return }
                            timeTrigger.weeklyWeekday = day
                            automations[index] = .timeOfDay(timeTrigger)
                        }
                    )) {
                        ForEach(1...7, id: \.self) { day in
                            Text(Calendar.current.weekdaySymbols[day - 1]).tag(day)
                        }
                    }
                    .pickerStyle(.segmented)
                case .monthly:
                    Stepper(
                        "ui.automation.month_day_fmt".localizedFormat(String(timeTrigger.monthlyDay ?? 1)),
                        value: Binding(
                            get: { timeTrigger.monthlyDay ?? 1 },
                            set: { day in
                                guard let index else { return }
                                timeTrigger.monthlyDay = day
                                automations[index] = .timeOfDay(timeTrigger)
                            }
                        ),
                        in: 1...31
                    )
                    .font(.caption)
                case .custom:
                    HStack(spacing: 4) {
                        ForEach(1...7, id: \.self) { day in
                            let selected = timeTrigger.customWeekdays?.contains(day) ?? false
                            Button {
                                guard let index else { return }
                                var days = timeTrigger.customWeekdays ?? []
                                if selected { days.remove(day) } else { days.insert(day) }
                                timeTrigger.customWeekdays = days
                                automations[index] = .timeOfDay(timeTrigger)
                            } label: {
                                Text(String(Calendar.current.weekdaySymbols[day - 1].prefix(1)))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .tint(selected ? .accentColor : nil)
                        }
                    }
                default:
                    EmptyView()
                }
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - 트리거별 상세 설정

    /// 파일·드라이브·디스플레이·앱 트리거의 대상과 이벤트를 편집한다.
    @ViewBuilder
    private func triggerDetailEditor(for trigger: AutomationTrigger) -> some View {
        switch trigger {
        case .folder(let value):
            pathField(
                title: "ui.automation.folder_path".localized,
                value: value.folderPath,
                isDirectory: true
            ) { newValue in
                update(trigger) { updated in
                    if case .folder(var folder) = updated {
                        folder.folderPath = newValue
                        updated = .folder(folder)
                    }
                }
            }

        case .file(let value):
            pathField(
                title: "ui.automation.file_path".localized,
                value: value.filePath,
                isDirectory: false
            ) { newValue in
                update(trigger) { updated in
                    if case .file(var file) = updated {
                        file.filePath = newValue
                        updated = .file(file)
                    }
                }
            }

        case .externalDrive(let value):
            VStack(alignment: .leading, spacing: 6) {
                textField(
                    title: "ui.automation.drive_name".localized,
                    hint: "ui.automation.drive_name_hint".localized,
                    value: value.driveName ?? ""
                ) { newValue in
                    update(trigger) { updated in
                        if case .externalDrive(var drive) = updated {
                            drive.driveName = newValue.isEmpty ? nil : newValue
                            updated = .externalDrive(drive)
                        }
                    }
                }
                HStack(spacing: 14) {
                    eventToggle("ui.trigger.connected".localized, isOn: value.eventTypes.contains(.mounted)) { on in
                        updateEventTypes(trigger, type: DriveEventType.mounted, isOn: on)
                    }
                    eventToggle("ui.trigger.disconnected".localized, isOn: value.eventTypes.contains(.unmounted)) { on in
                        updateEventTypes(trigger, type: DriveEventType.unmounted, isOn: on)
                    }
                }
            }

        case .display(let value):
            HStack(spacing: 14) {
                eventToggle("ui.trigger.connected".localized, isOn: value.eventTypes.contains(.connected)) { on in
                    updateEventTypes(trigger, type: DisplayEventType.connected, isOn: on)
                }
                eventToggle("ui.trigger.disconnected".localized, isOn: value.eventTypes.contains(.disconnected)) { on in
                    updateEventTypes(trigger, type: DisplayEventType.disconnected, isOn: on)
                }
            }

        case .app(let value):
            VStack(alignment: .leading, spacing: 6) {
                textField(
                    title: "ui.automation.app_bundle".localized,
                    hint: "ui.automation.app_bundle_hint".localized,
                    value: value.bundleID
                ) { newValue in
                    update(trigger) { updated in
                        if case .app(var app) = updated {
                            app.bundleID = newValue
                            updated = .app(app)
                        }
                    }
                }
                HStack(spacing: 12) {
                    ForEach(AppEventType.allCases) { eventType in
                        eventToggle(eventType.displayName, isOn: value.eventTypes.contains(eventType)) { on in
                            updateEventTypes(trigger, type: eventType, isOn: on)
                        }
                    }
                }
            }

        default:
            EmptyView()
        }
    }

    private func update(_ trigger: AutomationTrigger, _ body: (inout AutomationTrigger) -> Void) {
        guard let index = automations.firstIndex(where: { $0.id == trigger.id }) else { return }
        var value = automations[index]
        body(&value)
        automations[index] = value
    }

    private func updateEventTypes<T: Hashable>(
        _ trigger: AutomationTrigger,
        type: T,
        isOn: Bool
    ) {
        update(trigger) { updated in
            switch updated {
            case .externalDrive(var drive):
                guard let event = type as? DriveEventType else { return }
                if isOn { drive.eventTypes.insert(event) } else { drive.eventTypes.remove(event) }
                updated = .externalDrive(drive)
            case .display(var display):
                guard let event = type as? DisplayEventType else { return }
                if isOn { display.eventTypes.insert(event) } else { display.eventTypes.remove(event) }
                updated = .display(display)
            case .app(var app):
                guard let event = type as? AppEventType else { return }
                if isOn { app.eventTypes.insert(event) } else { app.eventTypes.remove(event) }
                updated = .app(app)
            default:
                break
            }
        }
    }

    private func pathField(
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
                TextField("ui.automation.path_hint".localized, text: Binding(
                    get: { value },
                    set: onChange
                ))
                .textFieldStyle(.roundedBorder)
                Button("ui.browse".localized) {
                    choosePath(isDirectory: isDirectory, onChange: onChange)
                }
                .controlSize(.small)
            }
        }
    }

    private func textField(
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

    private func eventToggle(
        _ title: String,
        isOn: Bool,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        Toggle(title, isOn: Binding(get: { isOn }, set: onChange))
            .toggleStyle(.checkbox)
            .controlSize(.small)
    }

    private func choosePath(isDirectory: Bool, onChange: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = !isDirectory
        panel.canChooseDirectories = isDirectory
        panel.canCreateDirectories = isDirectory
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            onChange(url.path)
        }
    }

    // MARK: - 추가 섹션
    
    private var addSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ui.automation.add_trigger".localized)
                .font(.headline)
            
            Picker("ui.category".localized, selection: $newTriggerType) {
                ForEach(categories) { category in
                    Label(category.displayName, systemImage: category.systemImage).tag(category)
                }
            }
            .pickerStyle(.menu)
            
            triggerCreationChoices
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    /// 카테고리별 트리거 생성 버튼
    private var triggerCreationChoices: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch newTriggerType {
            case .time:
                addTriggerButton(title: "ui.automation.time".localized, icon: "clock") {
                    add(.timeOfDay(TimeOfDayTrigger(time: DateComponents(hour: 9, minute: 0), repeatRule: .daily)))
                }
            case .filesystem:
                addTriggerButton(title: "ui.automation.folder".localized, icon: "folder") {
                    add(.folder(FolderTrigger(folderPath: "")))
                }
                addTriggerButton(title: "ui.automation.file".localized, icon: "doc.badge.gearshape") {
                    add(.file(FileTrigger(filePath: "")))
                }
            case .hardware:
                addTriggerButton(title: "ui.automation.external_drive".localized, icon: "externaldrive") {
                    add(.externalDrive(ExternalDriveTrigger()))
                }
                addTriggerButton(title: "ui.automation.display".localized, icon: "display") {
                    add(.display(DisplayTrigger()))
                }
            case .system:
                addTriggerButton(title: "ui.automation.app".localized, icon: "app.badge") {
                    add(.app(AppTrigger(bundleID: "")))
                }
            case .power:
                addTriggerButton(title: "ui.automation.battery".localized, icon: "battery.100") {
                    add(.battery(BatteryTrigger(condition: .fallsBelow, threshold: 0.2)))
                }
                addTriggerButton(title: "ui.automation.charger".localized, icon: "bolt.fill") {
                    add(.charger(ChargerTrigger(eventTypes: [.connected])))
                }
            default:
                Text("ui.automation.macos_only".localizedFormat(newTriggerType.displayName))
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }
        }
    }
    
    private func addTriggerButton(title: String, icon: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
                if enabled {
                    Image(systemName: "plus")
                } else {
                    Text("ui.automation.soon".localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.accentColor.opacity(enabled ? 0.1 : 0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.6)
    }
    
    private func add(_ trigger: AutomationTrigger) {
        automations.append(trigger)
    }
    
    // MARK: - 색상
    
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
