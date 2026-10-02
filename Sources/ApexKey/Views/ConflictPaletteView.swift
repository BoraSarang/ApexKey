import AppKit
import SwiftUI

/// Conflict palette — 같은 단축키의 실행 후보 선택.
/// ↑↓ 이동·↩ 실행·esc 취소·⌘↩ 고정(다음부터 바로 실행).
struct ConflictPaletteView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    let comboDisplay: String
    let targets: [HotKeyConflict.Target]
    var onPick: (HotKeyConflict.Target) -> Void
    var onPin: (HotKeyConflict.Target) -> Void

    @State private var selectedIndex = 0
    @State private var monitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .foregroundColor(theme.secondaryText)
                Text(comboDisplay)
                    .font(.system(.body, design: .monospaced))
                Text("conflict.count".localizedFormat(targets.count))
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                Spacer()
                Text("palette.esc_key".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText.opacity(0.6))
            }
            .padding(12)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(targets.enumerated()), id: \.element.id) { index, target in
                        Button { pick(target) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: target.kind == .shortcut ? "bolt.fill" : "app.badge")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.secondaryText)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(target.title)
                                        .font(.system(size: 13))
                                        .lineLimit(1)
                                    Text(target.subtitle)
                                        .font(.caption)
                                        .foregroundColor(theme.secondaryText)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background {
                                if index == selectedIndex {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.accentColor.opacity(0.3))
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 6)
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(maxHeight: 300)
            Divider()
            Text("conflict.footer".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .frame(width: 480)
        .background(theme.primaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 12)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.secondaryBorder)
        }
        .onAppear { installMonitor() }
        .onDisappear { removeMonitor() }
        .onKeyPress(.upArrow) {
            guard !targets.isEmpty else { return .handled }
            selectedIndex = (selectedIndex - 1 + targets.count) % targets.count
            return .handled
        }
        .onKeyPress(.downArrow) {
            guard !targets.isEmpty else { return .handled }
            selectedIndex = (selectedIndex + 1) % targets.count
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onKeyPress(.return) {
            guard targets.indices.contains(selectedIndex) else { return .handled }
            pick(targets[selectedIndex])
            return .handled
        }
    }

    private func pick(_ target: HotKeyConflict.Target) {
        dismiss()
        onPick(target)
    }

    /// ⌘↩ 고정은 onKeyPress에 modifiers 오버로드가 없어 NSEvent로 처리.
    /// View struct 캡처는 stale이 되므로 필요한 것만 Binding/값으로 명시 캡처한다.
    private func installMonitor() {
        let indexBinding = $selectedIndex
        let list = targets
        let pin = onPin
        let doDismiss = dismiss
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated { () -> NSEvent? in
                // Return + Command (Option 제외)
                if event.keyCode == 36, event.modifierFlags.contains(.command),
                   !event.modifierFlags.contains(.option) {
                    if list.indices.contains(indexBinding.wrappedValue) {
                        let target = list[indexBinding.wrappedValue]
                        doDismiss()
                        pin(target)
                    }
                    return nil
                }
                return event
            }
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        self.monitor = nil
    }
}
