import SwiftUI

/// Auto-growing multiline editor for step settings windows.
///
/// Fixed-height `TextEditor`s either clip long scripts or leave dead space
/// below short ones. This wrapper measures the text with a hidden `Text` of
/// the same font/width, grows from `minHeight` up to `maxHeight` as content
/// grows, and only scrolls internally past the cap — the outer settings
/// `ScrollView` stays still.
struct GrowingTextEditor: View {
    @Environment(\.theme) private var theme
    @Binding var text: String
    var font: Font = .system(.body, design: .monospaced)
    var minHeight: CGFloat = 180
    var maxHeight: CGFloat = 320
    var borderColor: Color?
    /// true면 내용을 측정하지 않고 남은 공간을 모두 차지한다 (고정 크기 창의 스크립트 입력용).
    /// 외곽 ScrollView 없이 쓰며, 넘치는 내용은 입력칸 내부에서만 스크롤된다.
    var fillAvailable = false

    @State private var measuredHeight: CGFloat = 0

    var body: some View {
        TextEditor(text: $text)
            .font(font)
            .frame(minHeight: minHeight, maxHeight: fillAvailable ? .infinity : editorHeight)
            .layoutPriority(fillAvailable ? 1 : 0)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor ?? theme.secondaryText.opacity(0.3))
            )
            .scrollContentBackground(.hidden)
            .background {
                if !fillAvailable {
                    Text(measurableText)
                        .font(font)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .hidden()
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(key: GrowingHeightKey.self, value: geo.size.height)
                            }
                        )
                }
            }
            .onPreferenceChange(GrowingHeightKey.self) { measuredHeight = $0 }
    }

    private var editorHeight: CGFloat {
        // Small fudge: NSTextView line fragments are slightly taller than
        // SwiftUI Text lines, so the editor must never be shorter than measured.
        min(max(measuredHeight + 12, minHeight), maxHeight)
    }

    /// Trailing newlines collapse in `Text` measurement — force the extra line.
    private var measurableText: String {
        if text.isEmpty { return " " }
        return text.hasSuffix("\n") ? text + " " : text
    }
}

private struct GrowingHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
