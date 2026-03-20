import Testing
import Foundation
@testable import Readability

/// Compatibility tests for cases captured via ReadabilityCLI (ex-pages/).
///
/// Each test method corresponds to one case committed with `swift run ReadabilityCLI commit`.
/// Add methods here manually after running `commit` — the command prints a ready-to-use template.
@Suite("Ex-pages Compatibility Tests")
struct ExPagesCompatibilityTests {

    private let defaultOptions = ReadabilityOptions(
        charThreshold: 500,
        classesToPreserve: ["caption"]
    )

    // MARK: - Tests

    // MARK: 1a23-1 · Holpxay Calculator (1a23.com)

    @Test("1a23-1 - Title matches expected")
    func test1a231Title() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-1", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-1'")
            return
        }
        let result = try Readability(html: testCase.sourceHTML, options: defaultOptions).parse()
        #expect(result.title == testCase.expectedMetadata.title)
    }

    @Test("1a23-1 - Byline matches expected")
    func test1a231Byline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-1", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-1'")
            return
        }
        let result = try Readability(html: testCase.sourceHTML, options: defaultOptions).parse()
        #expect(result.byline == testCase.expectedMetadata.byline)
    }

    @Test("1a23-1 - Content matches expected HTML")
    func test1a231Content() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-1", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-1'")
            return
        }
        let result = try Readability(html: testCase.sourceHTML, options: defaultOptions).parse()
        let (isEqual, diff) = DOMComparator.compare(result.content, testCase.expectedHTML)
        #expect(isEqual, "DOM mismatch:\n\(diff)")
    }

    // MARK: 1a23-2 · Have a wonderful 2026! (1a23.com)

    @Test("1a23-2 - Title matches expected")
    func test1a232Title() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-2", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-2'")
            return
        }
        let result = try Readability(html: testCase.sourceHTML, options: defaultOptions).parse()
        #expect(result.title == testCase.expectedMetadata.title)
    }

    @Test("1a23-2 - Byline matches expected")
    func test1a232Byline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-2", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-2'")
            return
        }
        let result = try Readability(html: testCase.sourceHTML, options: defaultOptions).parse()
        #expect(result.byline == testCase.expectedMetadata.byline)
    }

    @Test("1a23-2 - Content matches expected HTML")
    func test1a232Content() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-2", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-2'")
            return
        }
        let result = try Readability(html: testCase.sourceHTML, options: defaultOptions).parse()
        let (isEqual, diff) = DOMComparator.compare(result.content, testCase.expectedHTML)
        #expect(isEqual, "DOM mismatch:\n\(diff)")
    }

    // MARK: 1a23-3 · TRMNL recipies (1a23.com)

    @Test("1a23-3 - Title matches expected")
    func test1a233Title() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-3", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-3'")
            return
        }
        let result = try Readability(html: testCase.sourceHTML, options: defaultOptions).parse()
        #expect(result.title == testCase.expectedMetadata.title)
    }

    @Test("1a23-3 - Byline matches expected")
    func test1a233Byline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-3", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-3'")
            return
        }
        let result = try Readability(html: testCase.sourceHTML, options: defaultOptions).parse()
        #expect(result.byline == testCase.expectedMetadata.byline)
    }

    @Test("1a23-3 - Content matches expected HTML")
    func test1a233Content() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-3", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-3'")
            return
        }
        let result = try Readability(html: testCase.sourceHTML, options: defaultOptions).parse()
        let (isEqual, diff) = DOMComparator.compare(result.content, testCase.expectedHTML)
        #expect(isEqual, "DOM mismatch:\n\(diff)")
    }

    // MARK: antirez-1 · Coding with LLMs in the summer of 2025 (an update) (antirez.com)

    @Test("antirez-1 - Title matches expected")
    func testAntirez1Title() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "antirez-1", in: "ex-pages") else {
            Issue.record("Failed to load test case 'antirez-1'")
            return
        }
        let result = try Readability(html: testCase.sourceHTML, options: defaultOptions).parse()
        #expect(result.title == testCase.expectedMetadata.title)
    }

    @Test("antirez-1 - Byline matches expected")
    func testAntirez1Byline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "antirez-1", in: "ex-pages") else {
            Issue.record("Failed to load test case 'antirez-1'")
            return
        }
        let result = try Readability(html: testCase.sourceHTML, options: defaultOptions).parse()
        #expect(result.byline == testCase.expectedMetadata.byline)
    }

    @Test("antirez-1 - Excerpt matches expected")
    func testAntirez1Excerpt() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "antirez-1", in: "ex-pages") else {
            Issue.record("Failed to load test case 'antirez-1'")
            return
        }
        let result = try Readability(html: testCase.sourceHTML, options: defaultOptions).parse()
        #expect(result.excerpt == testCase.expectedMetadata.excerpt)
    }

    @Test("antirez-1 - Content matches expected HTML")
    func testAntirez1Content() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "antirez-1", in: "ex-pages") else {
            Issue.record("Failed to load test case 'antirez-1'")
            return
        }
        let result = try Readability(html: testCase.sourceHTML, options: defaultOptions).parse()
        let (isEqual, diff) = DOMComparator.compare(result.content, testCase.expectedHTML)
        #expect(isEqual, "DOM mismatch:\n\(diff)")
    }
}
