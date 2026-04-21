import Testing
@testable import Readability

@Suite("DOM Comparator Tests")
struct DOMComparatorTests {

    @Test("normal text comparison collapses HTML whitespace")
    func testNormalTextComparisonCollapsesHTMLWhitespace() {
        let comparison = DOMComparator.compare(
            "<article><p>Hello    world</p></article>",
            "<article><p>Hello world</p></article>"
        )
        #expect(comparison.isEqual)
    }

    @Test("boolean attributes compare by presence")
    func testBooleanAttributesCompareByPresence() {
        let comparison = DOMComparator.compare(
            "<article><iframe allowfullscreen></iframe></article>",
            "<article><iframe allowfullscreen=\"allowfullscreen\"></iframe></article>"
        )
        #expect(comparison.isEqual)
    }

    @Test("pre text comparison preserves indentation")
    func testPreTextComparisonPreservesIndentation() {
        let comparison = DOMComparator.compare(
            "<article><pre><code><span> return value;</span></code></pre></article>",
            "<article><pre><code><span>    return value;</span></code></pre></article>"
        )
        #expect(!comparison.isEqual)
        #expect(comparison.diff.contains("Text mismatch"))
    }

    @Test("pre text comparison preserves blank lines")
    func testPreTextComparisonPreservesBlankLines() {
        let comparison = DOMComparator.compare(
            "<article><pre><code>alpha\nbeta</code></pre></article>",
            "<article><pre><code>alpha\n\nbeta</code></pre></article>"
        )
        #expect(!comparison.isEqual)
        #expect(comparison.diff.contains("Text mismatch"))
    }
}
