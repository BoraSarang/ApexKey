import SwiftUI

/// 시스템 동작 탭 — 화면 잠금/음소거/다크모드에 글로벌 단축키 할당
struct SystemActionsView: View {
    @EnvironmentObject var store: ConfigStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("아이콘을 클릭해 시스템 동작에 글로벌 단축키를 할당하거나 직접 실행할 수 있습니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
        .sheet(item: $recordingType) { type in
            HotKeyRecorderView(
                title: "\(type.displayName) 단축키",
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
                Text("시스템 동작")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("화면 잠금 · 음소거 · 다크 모드")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                _ = SystemActionExecutor.execute(type)
            } label: {
                Label("실행", systemImage: "play")
            }
            .buttonStyle(.borderless)
            .help("지금 실행")
            Button {
                recordingType = type
            } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.borderless)
            .help("단축키 녹음")
            if !bindings.isEmpty {
                Button {
                    store.removeBinding(bindings.first!)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("단축키 삭제")
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func onRecord(combo: HotKeyCombo, type: SystemActionType) {
        guard !combo.isEmpty else { return }
        store.setSystemBinding(for: type, combo: combo)
    }
}
