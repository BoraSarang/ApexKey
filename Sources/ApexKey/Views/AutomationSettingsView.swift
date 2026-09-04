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
                Label("개인 자동화", systemImage: "bolt.badge.clock")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button("완료") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(16)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 기존 트리거 목록
                    if automations.isEmpty {
                        Text("등록된 자동화가 없습니다. 아래에서 트리거를 추가하세요.")
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
    
    // MARK: - 추가 섹션
    
    private var addSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("새 트리거 추가")
                .font(.headline)
            
            Picker("카테고리", selection: $newTriggerType) {
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
                addTriggerButton(title: "시간 (시간/일정)", icon: "clock") {
                    add(.timeOfDay(TimeOfDayTrigger(time: DateComponents(hour: 9, minute: 0), repeatRule: .daily)))
                }
            case .filesystem:
                addTriggerButton(title: "폴더 감시", icon: "folder") {
                    add(.folder(FolderTrigger(folderPath: "")))
                }
                addTriggerButton(title: "파일 감시", icon: "doc") {
                    add(.file(FileTrigger(filePath: "")))
                }
            case .power:
                addTriggerButton(title: "배터리", icon: "battery.100") {
                    add(.battery(BatteryTrigger(condition: .fallsBelow, threshold: 0.2)))
                }
                addTriggerButton(title: "충전기", icon: "bolt.fill") {
                    add(.charger(ChargerTrigger(eventTypes: [.connected])))
                }
            default:
                Text("\(newTriggerType.displayName) 트리거는 macOS 26 이상에서 지원됩니다.")
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }
        }
    }
    
    private func addTriggerButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
                Image(systemName: "plus")
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
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
