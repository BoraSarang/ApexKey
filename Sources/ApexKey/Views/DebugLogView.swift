import SwiftUI

/// 디버그 로그 뷰어 — Logger 링버퍼 표시 + 필터/복사/지우기
struct DebugLogView: View {
    @State private var filterText = ""
    @State private var refreshTick = 0
    @State private var autoScroll = true

    private var allLines: [String] {
        Logger.allLogs()
    }

    private var filteredLines: [String] {
        let q = filterText.lowercased()
        let lines = q.isEmpty ? allLines : allLines.filter { $0.lowercased().contains(q) }
        return autoScroll ? lines : lines
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            logList
        }
        .frame(minWidth: 480, minHeight: 300)
        .onAppear {
            Logger.onBufferChange = { refreshTick += 1 }
        }
        .onDisappear {
            Logger.onBufferChange = nil
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            TextField("필터 (E-MAC-… / tag / 단어)", text: $filterText)
                .textFieldStyle(.roundedBorder)
            Toggle("자동 스크롤", isOn: $autoScroll)
                .toggleStyle(.checkbox)
            Button {
                Logger.clearBuffer()
            } label: {
                Label("지우기", systemImage: "trash")
            }
            Button {
                copyToPasteboard()
            } label: {
                Label("복사", systemImage: "doc.on.doc")
            }
        }
        .padding(8)
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    if filteredLines.isEmpty { // refreshTick 의존 재렌더
                        Text(refreshTick < 0 ? "" : "로그 없음")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                    }
                    ForEach(Array(filteredLines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(color(for: line))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(index)
                    }
                }
                .padding(8)
            }
            .onChange(of: refreshTick) { _, _ in
                if autoScroll {
                    let count = filteredLines.count
                    if count > 0 {
                        withAnimation(.none) {
                            proxy.scrollTo(count - 1, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    private func color(for line: String) -> Color {
        if line.contains("[ERROR]") { return .red }
        if line.contains("[PERF]") { return .yellow }
        if line.contains("[HOTKEY]") { return .green }
        return .primary
    }

    private func copyToPasteboard() {
        let text = filteredLines.joined(separator: "\n")
        if !text.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }
}