import SwiftUI

/// 릴리스 노트(마크다운) 렌더링.
/// `AttributedString(markdown:)` 전체 구문 파싱은 블록 경계를 SwiftUI `Text`가
/// 줄바꿈으로 그려주지 않아 제목·목록이 한 덩어리로 붙는다 (가이드 실패2).
/// 검증된 방식: 줄 단위 블록 분류 + 인라인만 해석해 개행 보존.
/// - 주의: `Text(AttributedString)` 뒤에 `.font()`를 붙이면 run의 폰트 특성
///   (볼드 등)이 덮어버리므로 (가이드 실패3), 글자 크기는 run마다 직접 기록한다.
struct ReleaseNotesView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Block.parse(markdown)) { block in
                block.view
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 블록 모델

    struct Block: Identifiable {
        let id = UUID()
        let view: AnyView

        static func parse(_ markdown: String) -> [Block] {
            var blocks: [Block] = []
            var inCodeFence = false
            var codeLines: [String] = []

            func flushCode() {
                if !codeLines.isEmpty {
                    let text = codeLines.joined(separator: "\n")
                    blocks.append(Block(view: AnyView(codeBlock(text))))
                    codeLines = []
                }
            }

            for rawLine in markdown.components(separatedBy: "\n") {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("```") {
                    if inCodeFence { flushCode() }
                    inCodeFence.toggle()
                    continue
                }
                if inCodeFence {
                    codeLines.append(rawLine)
                    continue
                }
                if line.isEmpty {
                    blocks.append(Block(view: AnyView(Spacer().frame(height: 4))))
                    continue
                }
                if line.hasPrefix("### ") {
                    let text = String(line.dropFirst(4))
                    blocks.append(Block(view: AnyView(Text(styledInline(text, size: 13, bold: true)))))
                } else if line.hasPrefix("## ") {
                    let text = String(line.dropFirst(3))
                    blocks.append(Block(view: AnyView(Text(styledInline(text, size: 14, bold: true)))))
                } else if line.hasPrefix("# ") {
                    let text = String(line.dropFirst(2))
                    blocks.append(Block(view: AnyView(Text(styledInline(text, size: 15, bold: true)))))
                } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                    let text = String(line.dropFirst(2))
                    blocks.append(Block(view: AnyView(
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                            Text(styledInline(text, size: 13))
                        }
                    )))
                } else if let ordered = parseOrdered(line) {
                    blocks.append(Block(view: AnyView(
                        HStack(alignment: .top, spacing: 6) {
                            Text("\(ordered.number).")
                            Text(styledInline(ordered.text, size: 13))
                        }
                    )))
                } else if line.hasPrefix("> ") {
                    let text = String(line.dropFirst(2))
                    blocks.append(Block(view: AnyView(
                        Text(styledInline(text, size: 13))
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    )))
                } else {
                    blocks.append(Block(view: AnyView(Text(styledInline(line, size: 13)))))
                }
            }
            flushCode()
            return blocks
        }

        private static func parseOrdered(_ line: String) -> (number: Int, text: String)? {
            var digits = ""
            var idx = line.startIndex
            while idx < line.endIndex, line[idx].isNumber {
                digits.append(line[idx])
                idx = line.index(after: idx)
            }
            guard !digits.isEmpty, line[idx...].hasPrefix(". ") else { return nil }
            guard let number = Int(digits) else { return nil }
            return (number, String(line[line.index(idx, offsetBy: 2)...]))
        }

        private static func codeBlock(_ text: String) -> some View {
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    /// 인라인(굵기·기울임·코드)만 해석 — 한글 `**볼드**` 포함.
    static func styledInline(_ string: String, size: CGFloat, bold: Bool = false) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace)
        var attr = (try? AttributedString(markdown: string, options: options)) ?? AttributedString(string)
        for run in attr.runs {
            var font = Font.system(size: size)
            let intent = run.inlinePresentationIntent
            if bold || intent?.contains(.stronglyEmphasized) == true { font = font.bold() }
            if intent?.contains(.emphasized) == true { font = font.italic() }
            if intent?.contains(.code) == true {
                font = Font.system(size: size, design: .monospaced)
            }
            attr[run.range].font = font
        }
        return attr
    }
}
