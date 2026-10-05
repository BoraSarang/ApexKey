import SwiftUI

/// 시스템 프리셋 선택 — 워크플로우 안 System 카테고리.
/// 스크립트 표시·수정 없음. 고르면 target=프리셋 ID, title=프리셋명.
/// 수정 불가이므로 라벨이 거짓말할 수 없다 (lock 단계가 dark mode를 실행하는 사태 제거).
struct SystemPresetPickerView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep

    private var selected: SystemActionType? {
        SystemActionType(rawValue: step.target)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ui.app_detail.select_system".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            ForEach(SystemActionType.allCases) { type in
                presetRow(type)
            }
        }
        .sectionCard()
    }

    private func presetRow(_ type: SystemActionType) -> some View {
        let isSelected = selected == type
        return Button {
            step.target = type.rawValue
            step.title = type.displayName
        } label: {
            HStack(spacing: 10) {
                Image(systemName: type.systemImage)
                    .frame(width: 24)
                    .foregroundColor(theme.accentColor)
                Text(type.displayName)
                    .font(.body)
                    .foregroundColor(theme.primaryText)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? theme.accentColor : theme.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(theme.accentColor.opacity(isSelected ? 0.5 : 0), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
