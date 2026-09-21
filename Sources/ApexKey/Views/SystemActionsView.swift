import SwiftUI
import AppKit

/// 시스템 동작 탭 — 화면 잠금/음소거/다크모드에 글로벌 단축키 할당
struct SystemActionsView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("ui.system.intro".localized)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                    VStack(spacing: 8) {
                        ForEach(SystemActionType.allCases) { type in
                            row(for: type)
                        }
                    }
                    Spacer()
                }
                .padding(16)
            }
        }
        .frame(minWidth: 440, minHeight: 480)
        .background(theme.primaryBackground)
        .sheet(item: $recordingType) { type in
            HotKeyRecorderView(
                title: "ui.system.hotkey_title".localizedFormat(type.displayName),
                excludedCombo: store.systemBindings(for: type).first?.combo,
                onTest: { _ in SystemActionExecutor.execute(type) }
            ) { combo in
                onRecord(combo: combo, type: type)
            }
            .environmentObject(store)
        }
    }

    @State private var recordingType: SystemActionType?

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "gearshape.2")
                .frame(width: 36, height: 36)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("ui.system.title".localized)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("ui.system.assign_hotkey".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func row(for type: SystemActionType) -> some View {
        let bindings = store.systemBindings(for: type)
        let comboText = bindings.first?.combo.displayString ?? ""
        return HStack(spacing: 12) {
            Image(systemName: type.systemImage)
                .frame(width: 22)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayName)
                    .font(.body)
                if !comboText.isEmpty {
                    Text(comboText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.accentColor)
                }
            }
            Spacer()
            Button {
                // 스크립트형 액션(미러 등)은 수십 초 걸릴 수 있어 메인 스레드 차단 금지.
                // 백그라운드 실행 + 토스트로 결과 통지.
                let name = type.displayName
                let executor = store.actionExecutor
                DispatchQueue.global(qos: .userInitiated).async {
                    let detail = executor.executeWithDetail(HotKeyBinding(
                        combo: .empty,
                        actionType: .system,
                        target: type.rawValue,
                        title: name
                    ))
                    DispatchQueue.main.async {
                        (NSApp.delegate as? AppDelegate)?.showToast(
                            title: name,
                            message: detail.message,
                            success: detail.success
                        )
                    }
                }
            } label: {
                Label("ui.run".localized, systemImage: "play")
            }
            .buttonStyle(.borderless)
            .help("ui.system.run_now".localized)
            Button {
                recordingType = type
            } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.borderless)
            .help("ui.appdetail.record_hotkey".localized)
            if !bindings.isEmpty {
                Button {
                    store.removeBinding(bindings.first!)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(.borderless)
                .help("ui.system.delete_hotkey".localized)
            }
        }
        .padding(10)
        .background(theme.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func onRecord(combo: HotKeyCombo, type: SystemActionType) {
        guard !combo.isEmpty else { return }
        store.setSystemBinding(for: type, combo: combo)
    }
}
