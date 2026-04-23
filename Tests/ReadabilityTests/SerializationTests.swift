import Testing
@testable import Readability

@Suite("Serialization Tests")
struct SerializationTests {

    @Test("parse preserves pre code whitespace inside syntax highlight spans")
    func testParsePreservesPreCodeWhitespaceInsideSyntaxHighlightSpans() throws {
        let html = """
        <html>
        <body>
          <article>
            <h1>Code Sample</h1>
            <p>This is a sufficiently long paragraph, with commas, to satisfy scoring and extraction behavior.</p>
            <figure><pre><code><span class="line"><span class="kw">pub</span> fn main() {</span>
        <span class="line">    <span class="kw">return</span> value;</span>
        <span class="line">        deeperIndent();</span></code></pre></figure>
            <p>This trailing paragraph keeps the article shape stable for extraction.</p>
          </article>
        </body>
        </html>
        """

        let readability = try Readability(html: html)
        let result = try readability.parse()

        #expect(result.content.contains("<span>    <span>return</span> value;</span>"))
        #expect(result.content.contains("<span>        deeperIndent();</span>"))
        #expect(result.content.contains("</span>\n<span>    <span>return</span>"))
    }
}
