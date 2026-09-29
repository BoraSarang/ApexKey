import Foundation

/// HTML → Markdown 변환 (E-MAC-TEXT-6003)
///
/// **왜 직접 파싱하는가**: Foundation의 `NSAttributedString` HTML 임porter는
/// WebKit/`NSAttributedString.DocumentType.html`에 의존하고, 앱샌드박스 밖 파일을
/// 읽거나 스크립트를 실행하려 시도한다. 런처가 매 실행마다 그 경로를 타는 것은
/// 과하다. 변환 대상은 **정적인 프래그먼트**(이메일 본문, 웹페이지 일부)라
/// 작은 파서로 충분하다.
///
/// **중요 — "변환 실패"를 조용히 통과시키지 않는다.** 엉킨 HTML을 입력받아
/// 원문을 그대로 반환하면 사용자는 "변환기가 조용히 실패했다"를 알 수 없다.
/// 구조적으로 해석할 수 없는 입력이면 `FailureReason`을 돌려준다.
enum HTMLToMarkdown {

    enum Outcome: Equatable {
        case success(String)
        case failure(FailureReason)

        var text: String {
            if case .success(let t) = self { return t }
            return ""
        }

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }

    enum FailureReason: Equatable, Error {
        case emptyInput
        case noHTMLContent
        /// 구조적으로 해석 불가능 (예: 닫히지 않은 태그가 문서 끝을 넘어감)
        case unbalancedTags
        case tooDeep

        var messageKey: String {
            switch self {
            case .emptyInput: return "error.user.text_empty"
            case .noHTMLContent: return "error.user.text_no_html"
            case .unbalancedTags: return "error.user.text_html_unbalanced"
            case .tooDeep: return "error.user.text_html_too_deep"
            }
        }
    }

    /// 지원하는 인라인 태그
    private enum InlineTag: String {
        case b, strong, i, em, code, del, s, strike, a, br
    }

    /// 블록 요소 목록
    private static let blockTags: Set<String> = [
        "p", "div", "h1", "h2", "h3", "h4", "h5", "h6",
        "ul", "ol", "li", "blockquote", "pre", "hr", "table",
        "tr", "thead", "tbody", "br"
    ]

    /// 제거만 할 태그 (내용은 보존)
    private static let passthroughTags: Set<String> = [
        "span", "font", "small", "u", "ins", "mark", "sub", "sup", "tbody", "thead"
    ]

    /// 통째로 버릴 태그와 그 내용 (스크립트·스타일·메타는 사용자에게 불필요)
    private static let dropWithContent: Set<String> = ["script", "style", "head", "noscript", "iframe"]

    /// 최대 중첩 깊이 — `((((...` 로 스택을 터뜨리지 않기 위한 한계
    static let maxDepth = 64

    // MARK: - 진입점

    static func convert(_ input: String) -> Outcome {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.emptyInput)
        }
        let tokens = try? tokenize(input)
        guard var tokens, !tokens.isEmpty else {
            return .failure(.unbalancedTags)
        }
        // 태그가 하나도 없으면 "HTML이 아니다" — 원문을 그대로 내보내지 않는다
        // 닫는 태그만 있는 입력(`텍스트</div>`)도 HTML 마크업이다.
        // 열림 태그만 세면 이걸 "HTML 아님"으로 오판해 변환을 거부한다.
        let hasMarkup = tokens.contains { token in
            if case .text = token { return false }
            return true
        }
        guard hasMarkup else { return .failure(.noHTMLContent) }
        var builder = Builder()
        if case .failure(let reason) = render(tokens, into: &builder, depth: 0) {
            return .failure(reason)
        }
        return .success(normalize(builder.text))
    }

    // MARK: - 토크나이저

    enum Token: Equatable {
        case text(String)
        case openTag(String, [String: String])
        case closeTag(String)
    }

    /// HTML을 토큰으로 자른다. 태그가 improperly 닫혔으면 throw.
    static func tokenize(_ html: String) throws -> [Token] {
        var tokens: [Token] = []
        var index = html.startIndex
        var depth = 0
        var openStack: [String] = []

        while index < html.endIndex {
            guard let lt = html[index...].firstIndex(of: "<") else {
                let rest = String(html[index...])
                if !rest.isEmpty { tokens.append(.text(decodeEntities(rest))) }
                break
            }
            if lt > index {
                let chunk = String(html[index..<lt])
                if !chunk.isEmpty { tokens.append(.text(decodeEntities(chunk))) }
            }
            guard let gt = html[lt...].firstIndex(of: ">") else {
                // 닫히지 않은 태그 — 나머지를 텍스트로 취급한다
                let rest = String(html[lt...])
                if !rest.isEmpty { tokens.append(.text(decodeEntities(rest))) }
                break
            }
            let raw = String(html[html.index(after: lt)..<gt])
            index = html.index(after: gt)

            // 주석·DOCTYPE·CDATA
            if raw.hasPrefix("!") || raw.hasPrefix("?") { continue }

            if raw.hasPrefix("/") {
                let name = normalizeName(String(raw.dropFirst()))
                // 짝 없는 닫힘. 버리면 "HTML 마크업이 없다"고 오판돼 변환이 거부된다.
                // 토큰으로 남겨 렌더러가 무시하게 한다 (내용 손실 없음).
                guard let pos = openStack.lastIndex(of: name) else {
                    tokens.append(.closeTag(name))
                    continue
                }
                while openStack.count > pos {
                    tokens.append(.closeTag(openStack.removeLast()))
                }
                depth -= 1
                continue
            }
            // 셀프 클로징
            let selfClosing = raw.hasSuffix("/")
            let body = selfClosing ? String(raw.dropLast()) : raw
            let parts = body.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard let namePart = parts.first else { continue }
            let name = normalizeName(String(namePart))
            guard !name.isEmpty else { continue }
            let attrs = parseAttributes(parts.count > 1 ? String(parts[1]) : "")
            if selfClosing || name == "br" || name == "hr" || name == "img" {
                tokens.append(.openTag(name, attrs))
                tokens.append(.closeTag(name))
                continue
            }
            depth += 1
            if depth > maxDepth { throw FailureReason.tooDeep }
            openStack.append(name)
            tokens.append(.openTag(name, attrs))
        }
        // 스택에 남은 태그는 자동 닫힘으로 처리한다 — 실제 HTML도 브라우저가 그렇다.
        // (불균형을 "실패"로 만들면 이메일 조각 하나 때문에 전체 변환이 실패한다)
        while let last = openStack.popLast() {
            tokens.append(.closeTag(last))
        }
        return tokens
    }

    private static func normalizeName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func parseAttributes(_ raw: String) -> [String: String] {
        var attrs: [String: String] = [:]
        var current = ""
        var inQuote: Character?
        var chunks: [String] = []
        for ch in raw {
            if let q = inQuote {
                if ch == q { inQuote = nil } else { current.append(ch) }
            } else if ch == "\"" || ch == "'" {
                inQuote = ch
            } else if ch == "=" {
                chunks.append(current); current = ""
            } else if ch.isWhitespace {
                if !current.isEmpty { chunks.append(current); current = "" }
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { chunks.append(current) }
        guard chunks.count >= 2 else { return attrs }
        // key=value key2=value2 → 짝을 짓는다
        var i = 0
        while i + 1 < chunks.count {
            attrs[chunks[i].lowercased()] = decodeEntities(chunks[i + 1])
            i += 2
        }
        return attrs
    }

    // MARK: - 렌더러

    struct Builder {
        var text = ""
        /// 리스트 스택 — 중첩 리스트의 들여쓰기를 계산한다
        var listStack: [(ordered: Bool, index: Int)] = []
        var inPreformatted = false
        /// 현재 열려 있는 `<a>`의 href (중첩 링크는 비정상이라 마지막 값만 유지)
        var linkHref: String?
        var linkDepth = 0

        mutating func append(_ s: String) {
            if s.isEmpty { return }
            if inPreformatted {
                text += s
                return
            }
            // 공백은 한 번만
            if s == " " {
                if text.hasSuffix(" ") || text.hasSuffix("\n") || text.isEmpty { return }
                text += " "
                return
            }
            text += s
        }

        mutating func newline() {
            if text.hasSuffix("\n\n") || text.isEmpty { return }
            if text.hasSuffix("\n") { text += "\n" } else { text += "\n\n" }
        }
    }

    static func render(_ tokens: [Token], into builder: inout Builder, depth: Int) -> Outcome {
        guard depth <= maxDepth else { return .failure(.tooDeep) }
        var i = 0
        var dropUntil: String? = nil

        while i < tokens.count {
            let token = tokens[i]

            // 내용까지 버릴 태그 내부면 건너뛴다
            if let dropping = dropUntil {
                if case .closeTag(let name) = token, name == dropping { dropUntil = nil }
                i += 1
                continue
            }

            switch token {
            case .text(let s):
                builder.append(s)

            case .openTag(let name, let attrs):
                if dropWithContent.contains(name) {
                    dropUntil = name
                    i += 1
                    continue
                }
                switch name {
                case "h1", "h2", "h3", "h4", "h5", "h6":
                    let level = Int(name.dropFirst()) ?? 1
                    builder.newline()
                    builder.append(String(repeating: "#", count: min(level, 6)) + " ")
                case "strong", "b":
                    builder.append("**")
                case "i", "em":
                    builder.append("*")
                case "code":
                    if builder.inPreformatted { builder.append("`") } else { builder.append("`") }
                case "del", "s", "strike":
                    builder.append("~~")
                case "a":
                    let href = attrs["href"] ?? ""
                    builder.append("[")
                    builder.linkHref = href
                    builder.linkDepth += 1
                case "br":
                    builder.append("\n")
                case "hr":
                    builder.newline()
                    builder.append("---")
                    builder.newline()
                case "ul":
                    builder.newline()
                    builder.listStack.append((false, 0))
                case "ol":
                    builder.newline()
                    builder.listStack.append((true, 1))
                case "li":
                    builder.newline()
                    if let last = builder.listStack.last {
                        let indent = String(repeating: "  ", count: max(0, builder.listStack.count - 1))
                        if last.ordered {
                            builder.append("\(indent)\(last.index). ")
                            builder.listStack[builder.listStack.count - 1].index += 1
                        } else {
                            builder.append("\(indent)- ")
                        }
                    }
                case "blockquote":
                    builder.newline()
                    builder.append("> ")
                case "pre":
                    builder.newline()
                    builder.append("```\n")
                    builder.inPreformatted = true
                case "table", "thead", "tbody", "tr":
                    builder.newline()
                case "td", "th":
                    builder.append(" | ")
                case "img":
                    let alt = attrs["alt"] ?? ""
                    let src = attrs["src"] ?? ""
                    builder.append(alt.isEmpty ? "![](\(src))" : "![\(alt)](\(src))")
                case "p", "div", "span", "font", "small", "u", "ins", "mark", "sub", "sup":
                    if name == "p" || name == "div" { builder.newline() }
                default:
                    // `passthroughTags`와 알 수 없는 태그: 내용만 보존한다.
                    // 알 수 없는 태그를 통째로 버리면 내용이 사라져 데이터 손실이 된다.
                    if passthroughTags.contains(name) { builder.append("") }
                }

            case .closeTag(let name):
                switch name {
                case "strong", "b": builder.append("**")
                case "i", "em": builder.append("*")
                case "code": builder.append("`")
                case "del", "s", "strike": builder.append("~~")
                case "h1", "h2", "h3", "h4", "h5", "h6", "blockquote", "pre":
                    builder.append("\n")
                    if name == "pre" { builder.inPreformatted = false; builder.append("```") }
                case "ul", "ol":
                    if !builder.listStack.isEmpty { builder.listStack.removeLast() }
                    builder.newline()
                case "li":
                    builder.newline()
                case "a":
                    if builder.linkDepth > 0 {
                        builder.linkDepth -= 1
                        // `linkHref`는 Optional — 보간하면 `Optional("...")`가 그대로 출력된다
                        let href = builder.linkHref ?? ""
                        builder.linkHref = nil
                        builder.append("](\(href))")
                    }
                case "p", "div":
                    builder.newline()
                default:
                    break
                }
            }
            i += 1
        }
        return .success(builder.text)
    }

    // MARK: - 후처리

    /// 블록 마커 주변 공백 정리 + 인라인 공백 접합
    static func normalize(_ raw: String) -> String {
        var s = raw
        // 블록 경계에 붙은 공백 제거 (마커가 소용없어지지 않게)
        let blockMarkers = ["**", "~~", "*", "`"]
        for marker in blockMarkers {
            s = s.replacingOccurrences(of: " \(marker) ", with: marker)
            s = s.replacingOccurrences(of: " \(marker)\n", with: "\(marker)\n")
            s = s.replacingOccurrences(of: "\n \(marker)", with: "\n\(marker)")
        }
        // 링크 라벨 안 공백 제거 — `[ �스트 ](url)` → `[텍스트](url)`
        s = s.replacingOccurrences(of: "[ ", with: "[")
        s = s.replacingOccurrences(of: " ]", with: "]")
        // 3줄 이상 빈 줄 → 2줄
        while s.contains("\n\n\n") {
            s = s.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        // 공백 줄 제거
        s = s.replacingOccurrences(of: "\n \n", with: "\n\n")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 엔티티

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "nbsp": " ", "hellip": "…", "mdash": "—", "ndash": "–",
        "lsquo": "'", "rsquo": "'", "ldquo": "\u{201C}", "rdquo": "\u{201D}",
        "copy": "©", "reg": "®", "trade": "™", "middot": "·", "bull": "•",
        "deg": "°", "plusmn": "±", "times": "×", "divide": "÷", "laquo": "«", "raquo": "»"
    ]

    /// HTML 엔티티 디코딩 (`&amp;` → `&`, `&#39;` → `'`, `&#x27;` → `'`)
    static func decodeEntities(_ input: String) -> String {
        guard input.contains("&") else { return input }
        var out = ""
        var rest = Substring(input)
        while let amp = rest.firstIndex(of: "&") {
            out += rest[rest.startIndex..<amp]
            let afterAmp = rest.index(after: amp)
            // 엔티티는 짧다 — 무한 스캔을 막기 위해 `;`를 최대 12자 안에서만 찾는다
            let limit = rest.index(afterAmp, offsetBy: 12, limitedBy: rest.endIndex) ?? rest.endIndex
            guard let semi = rest[afterAmp..<limit].firstIndex(of: ";"), semi > afterAmp else {
                out.append("&")
                rest = rest[afterAmp...]
                continue
            }
            let body = String(rest[afterAmp..<semi])
            if body.hasPrefix("#x") || body.hasPrefix("#X") {
                if let code = UInt32(body.dropFirst(2), radix: 16),
                   let scalar = Unicode.Scalar(code) {
                    out.unicodeScalars.append(scalar)
                } else {
                    out += "&\(body);"
                }
            } else if body.hasPrefix("#") {
                if let code = UInt32(body.dropFirst()), let scalar = Unicode.Scalar(code) {
                    out.unicodeScalars.append(scalar)
                } else {
                    out += "&\(body);"
                }
            } else if let mapped = namedEntities[body.lowercased()] {
                out += mapped
            } else {
                out += "&\(body);"
            }
            rest = rest[rest.index(after: semi)...]
        }
        out += rest
        return out
    }
}
