import SwiftUI

/// Run Shortcut 단계 설정 — **호출할 동작을 고른다** (E-MAC-FLOW-7011)
///
/// 왜 전용 UI가 필요했나:
/// `executeRunShortcut`는 `step.target`에 **UUID 문자열**을 담아 받는다. 전용 UI가
/// 없으면 단계 설정이 `DefaultSettingsView`(자유 입력 필드)로 떨어져서, 사용자가
/// UUID를 직접 찾아 입력해야 했다. 엔진은 정상인데 **아무도 못 쓰는 기능**이 된다.
///
/// **자기 자신을 고를 수 없게 한다.** 자기 자신을 부르면 재귀 호출이 되고,
/// `execute`의 depth 제한에 걸리기까지 사용자는 이유를 모른다.
struct RunShortcutSettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: ConfigStore
    @Binding var step: ShortcutStep

    /// 편집 중인 동작의 ID — 자기 자신 제외용
    var currentShortcutID: UUID?

    /// 현재 저장된 대상 UUID
    private var selectedID: UUID? {
        UUID(uuidString: step.target)
    }

    /// 선택 가능한 후보 — 자기 자신 제외 + 이름순
    private var candidates: [ShortcutItem] {
        store.shortcuts
            .filter { $0.id != currentShortcutID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// 지금 저장된 대상이 후보에 없는 상태 (동작이 삭제됨)
    private var targetMissing: Bool {
        guard let id = selectedID else { return false }
        return !store.shortcuts.contains { $0.id == id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("step.run_shortcut_picker".localized)
                .font(.headline)

            if candidates.isEmpty {
                // 후보가 없으면 "없음"만 보여준다. 빈 피커보다 이유를 알려야 한다
                Text("ui.run_shortcut.no_candidates".localized)
                    .font(.callout)
                    .foregroundColor(theme.secondaryText)
            } else {
                Picker("ui.run_shortcut.target".localized, selection: binding) {
                    Text("ui.run_shortcut.none".localized).tag(UUID?.none)
                    ForEach(candidates) { s in
                        Text(s.name).tag(UUID?.some(s.id))
                    }
                }
                .pickerStyle(.menu)
            }

            if targetMissing {
                // 대상 동작이 삭제된 경우 — 조용히 빈 값으로 보이면 안 된다
                Label("ui.run_shortcut.target_missing".localized, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            if let selectedID, let target = store.shortcuts.first(where: { $0.id == selectedID }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ui.run_shortcut.preview".localized)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                    Text(target.steps.isEmpty
                         ? "ui.run_shortcut.preview_empty".localized
                         : target.steps.enumerated().map { "\($0.offset + 1). \($0.element.summary)" }
                            .joined(separator: "\n"))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(theme.secondaryText)
                        .textSelection(.enabled)
                }
            }

            Text("ui.run_shortcut.recursion_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)

            Spacer()
        }
        .padding(16)
    }

    /// target UUID를 안전하게 갱신한다.
    ///
    /// `""` 가 아니라 **UUID 문자열**을 그대로 쓴다 — 엔진이 파싱하므로 형식이 틀리면
    /// 실행 시점에 조용히 실패한다. 비우면 nil로 기록한다.
    private var binding: Binding<UUID?> {
        Binding(
            get: { selectedID },
            set: { newValue in
                step.target = newValue?.uuidString ?? ""
                // 제목에도 반영 — 단계 목록에서 "단축어 실행: (이름)"으로 보여야 한다
                if let newValue, let target = store.shortcuts.first(where: { $0.id == newValue }) {
                    step.title = target.name
                } else {
                    step.title = ""
                }
            }
        )
    }
}
