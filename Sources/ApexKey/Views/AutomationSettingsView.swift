import SwiftUI

/// 단축어 자동화(트리거) 설정 화면
struct AutomationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Binding var automations: [AutomationTrigger]
    
    @State private var newTriggerType: TriggerCategory = .time
    
    private let categories: [TriggerCategory] = TriggerCategory.allCases
    
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
                // 단일 파일 트리거는 감시자 미구현 — 추가 버튼 비활성 (P1)
                addTriggerButton(title: "ui.automation.file".localized, icon: "doc", enabled: false) {
                    add(.file(FileTrigger(filePath: "")))
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
