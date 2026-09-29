import XCTest
@testable import ApexKey

/// HTML → Markdown 변환 테스트 (E-MAC-TEXT-6003)
///
/// 왜 직접 파서인지: Foundation의 HTML 임포트는 WebKit에 의존하고 샌드박스 밖 접근을
/// 시도한다. 이 테스트는 그 경로를 타지 않는 변환기의 **순수 로직**만 검증한다.
final class HTMLToMarkdownTests: XCTestCase {

    private func md(_ html: String) -> String {
        let r = HTMLToMarkdown.convert(html)
        XCTAssertTrue(r.isSuccess, "변환 실패: \(r) — \(html)")
        return r.text
    }

    // MARK: - 인라인

    func testBoldItalicCode() {
        XCTAssertEqual(md("<b>굵게</b>"), "**굵게**")
        XCTAssertEqual(md("<strong>굵게</strong>"), "**굵게**")
        XCTAssertEqual(md("<i>기울임</i>"), "*기울임*")
        XCTAssertEqual(md("<em>기울임</em>"), "*기울임*")
        XCTAssertEqual(md("<del>지움</del>"), "~~지움~~")
    }

    func testLinkKeepsHref() {
        XCTAssertEqual(md(#"<a href="https://example.com">링크</a>"#), "[링크](https://example.com)")
    }

    func testLinkWithoutHrefStillShowsText() {
        // href가 없으면 라벨만 남는다 — 내용 손실이 우선이다
        XCTAssertEqual(md("<a>링크</a>"), "[링크]()")
    }

    func testLineBreak() {
        XCTAssertTrue(md("첫째<br>둘째").contains("\n"))
    }

    // MARK: - 블록

    func testHeadings() {
        XCTAssertTrue(md("<h1>제목</h1>").contains("# 제목"))
        XCTAssertTrue(md("<h3>제목</h3>").contains("### 제목"))
    }

    func testUnorderedList() {
        let out = md("<ul><li>하나</li><li>둘</li></ul>")
        XCTAssertTrue(out.contains("- 하나"), out)
        XCTAssertTrue(out.contains("- 둘"), out)
    }

    func testOrderedListNumbersIncrement() {
        let out = md("<ol><li>첫</li><li>둘</li><li>셋</li></ol>")
        XCTAssertTrue(out.contains("1. 첫"), out)
        XCTAssertTrue(out.contains("2. 둘"), out)
        XCTAssertTrue(out.contains("3. 셋"), out)
    }

    func testNestedListIndents() {
        let out = md("<ul><li>바깥<ul><li>안쪽</li></ul></li></ul>")
        XCTAssertTrue(out.contains("- 바깥"), out)
        XCTAssertTrue(out.contains("  - 안쪽"), out)
    }

    func testParagraphSeparation() {
        let out = md("<p>첫 문단</p><p>둘째 문단</p>")
        XCTAssertTrue(out.contains("첫 문단"))
        XCTAssertTrue(out.contains("둘째 문단"))
        XCTAssertTrue(out.contains("\n\n") || out.contains("\n"), "문단이 붙었다: \(out.debugDescription)")
    }

    func testBlockquote() {
        XCTAssertTrue(md("<blockquote>인용</blockquote>").contains("> 인용"))
    }

    func testCodeBlock() {
        let out = md("<pre><code>let x = 1</code></pre>")
        XCTAssertTrue(out.contains("let x = 1"), out)
        XCTAssertTrue(out.contains("```"), out)
    }

    // MARK: - 제거 (사용자에게 불필요한 것)

    func testScriptAndStyleContentIsDropped() {
        // 스크립트 본문이 Markdown에 새면 **출력이 오염된다**
        let out = md("<p>본문</p><script>alert('x')</script><style>p{color:red}</style>")
        XCTAssertTrue(out.contains("본문"))
        XCTAssertFalse(out.contains("alert"), "스크립트가 남았다")
        XCTAssertFalse(out.contains("color:red"), "스타일이 남았다")
    }

    func testCommentsAndDoctypeAreDropped() {
        let out = md("<!DOCTYPE html><!-- 숨겨진 주석 --><p>본문</p>")
        XCTAssertFalse(out.contains("주석"), out)
        XCTAssertFalse(out.contains("DOCTYPE"), out)
        XCTAssertTrue(out.contains("본문"))
    }

    // MARK: - 엔티티

    func testNamedEntities() {
        XCTAssertEqual(HTMLToMarkdown.decodeEntities("A&amp;B"), "A&B")
        XCTAssertEqual(HTMLToMarkdown.decodeEntities("&lt;div&gt;"), "<div>")
        XCTAssertEqual(HTMLToMarkdown.decodeEntities("&quot;quoted&quot;"), "\"quoted\"")
        XCTAssertEqual(HTMLToMarkdown.decodeEntities("a&nbsp;b"), "a b")
    }

    func testNumericEntities() {
        XCTAssertEqual(HTMLToMarkdown.decodeEntities("&#39;"), "'")
        XCTAssertEqual(HTMLToMarkdown.decodeEntities("&#x27;"), "'")
        XCTAssertEqual(HTMLToMarkdown.decodeEntities("&#65;"), "A")
        XCTAssertEqual(HTMLToMarkdown.decodeEntities("&#x41;"), "A")
    }

    func testEntitiesInContext() {
        XCTAssertEqual(md("<p>Tom &amp; Jerry</p>"), "Tom & Jerry")
    }

    func testUnknownEntityIsPreservedVerbatim() {
        // 모르는 엔티티를 지우면 내용이 사라진다
        XCTAssertEqual(HTMLToMarkdown.decodeEntities("&unknownthing;"), "&unknownthing;")
    }

    func testBareAmpersandDoesNotLoop() {
        // `&` 만 있는 입력이 무한 루프에 빠지지 않아야 한다
        XCTAssertEqual(HTMLToMarkdown.decodeEntities("a & b"), "a & b")
        XCTAssertEqual(HTMLToMarkdown.decodeEntities("&"), "&")
        XCTAssertEqual(HTMLToMarkdown.decodeEntities("&&&"), "&&&")
    }

    // MARK: - 실패 (조용히 통과시키지 않는다)

    func testEmptyInputIsFailure() {
        XCTAssertEqual(HTMLToMarkdown.convert(""), .failure(.emptyInput))
        XCTAssertEqual(HTMLToMarkdown.convert("   \n "), .failure(.emptyInput))
    }

    func testTextWithoutTagsIsFailure() {
        // 원문을 그대로 돌려주면 "변환기가 조용히 실패했다"를 알 수 없다
        XCTAssertEqual(HTMLToMarkdown.convert(" 그냥 평문입니다 "), .failure(.noHTMLContent))
    }

    // MARK: - 견고성 (실제 웹 HTML은 지저분하다)

    func testUnclosedTagsAutoClose() {
        // 이메일 조각 하나 때문에 전체 변환이 실패하면 안 된다
        let out = md("<p>닫히지 않음")
        XCTAssertTrue(out.contains("닫히지 않음"), out)
    }

    func testStrayCloseTagIsIgnored() {
        XCTAssertTrue(md("텍스트</div>").contains("텍스트"))
    }

    func testSelfClosingTags() {
        XCTAssertTrue(md("줄<br/>바꿈").contains("\n"))
        XCTAssertTrue(md("a<hr>b").contains("---"))
    }

    func testUnknownTagsPreserveContent() {
        // 알 수 없는 태그를 통째로 버리면 내용이 사라진다 — 데이터 손실
        let out = md("<custom-widget>중요한 내용</custom-widget>")
        XCTAssertTrue(out.contains("중요한 내용"), out)
    }

    func testAttributeWithoutQuotes() {
        let out = md("<a href=https://example.com>링크</a>")
        XCTAssertTrue(out.contains("https://example.com"), out)
    }

    func testUppercaseTagNames() {
        XCTAssertTrue(md("<B>굵게</B>").contains("**굵게**"))
    }

    func testDeeplyNestedTagsDoNotCrash() {
        let depth = 500
        let html = String(repeating: "<div>", count: depth) + "내용" + String(repeating: "</div>", count: depth)
        let r = HTMLToMarkdown.convert(html)
        // 크래시하지 않는 것이 최소 조건 — 실패해도 정직하게 실패해야 한다
        if case .failure = r {
            XCTAssertTrue(true)
        } else {
            XCTAssertTrue(r.text.contains("내용"), "중첩이 깊어도 내용은 보존돼야 한다")
        }
    }

    func testRealisticEmailFragment() {
        let html = """
        <html><head><title>제목</title></head><body>
        <h1>안녕하세요</h1>
        <p>안내 <b>문자</b>입니다. <a href="https://x.kr">자세히 보기</a></p>
        <ul><li>첫째</li><li>둘째</li></ul>
        <p style="color:red">인라인 스타일은 무시</p>
        <script>track()</script>
        </body></html>
        """
        let out = md(html)
        XCTAssertTrue(out.contains("# 안녕하세요"), out)
        XCTAssertTrue(out.contains("**문자**"), out)
        XCTAssertTrue(out.contains("[자세히 보기](https://x.kr)"), out)
        XCTAssertTrue(out.contains("- 첫째"), out)
        XCTAssertTrue(out.contains("- 둘째"), out)
        XCTAssertFalse(out.contains("track()"), "스크립트가 남았다")
        XCTAssertFalse(out.contains("color:red"), "인라인 스타일이 남았다")
    }
}
