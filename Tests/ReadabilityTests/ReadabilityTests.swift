import Testing
import Foundation
import SwiftSoup
@testable import Readability

@Suite("Readability Lifecycle Tests")
struct ReadabilityTests {

    @Test("parse succeeds once and rejects repeated invocation")
    func testParseIsSingleUseAfterSuccess() throws {
        let html = """
        <html>
        <body>
          <article>
            <h1>Sample Title</h1>
            <p>This is a sufficiently long paragraph, with commas, to satisfy scoring and extraction.</p>
          </article>
        </body>
        </html>
        """

        let readability = try Readability(html: html)
        let first = try readability.parse()
        #expect(first.title == "Sample Title")

        do {
            _ = try readability.parse()
            Issue.record("Expected second parse to throw alreadyParsed")
        } catch ReadabilityError.alreadyParsed {
            // expected
        } catch {
            Issue.record("Expected alreadyParsed, got: \(error)")
        }
    }

    @Test("parse rejects repeated invocation after failure")
    func testParseIsSingleUseAfterFailure() throws {
        let html = "<html><body></body></html>"
        let readability = try Readability(html: html)

        do {
            _ = try readability.parse()
            Issue.record("Expected first parse to fail on empty document")
        } catch ReadabilityError.alreadyParsed {
            Issue.record("First parse must not fail with alreadyParsed")
        } catch {
            // Expected: parse may fail with noContent/contentTooShort depending internals.
        }

        do {
            _ = try readability.parse()
            Issue.record("Expected second parse to throw alreadyParsed")
        } catch ReadabilityError.alreadyParsed {
            // expected
        } catch {
            Issue.record("Expected alreadyParsed, got: \(error)")
        }
    }

    @Test("parse prefers extracted byline over social handle metadata")
    func testBylinePrefersExtractedNameOverSocialHandle() throws {
        let html = """
        <html>
        <head>
          <meta property="twitter:creator" content="@erinmcunningham">
        </head>
        <body>
          <article>
            <div class="byline">By Erin Cunningham</div>
            <p>This is a sufficiently long paragraph, with commas, to satisfy scoring and extraction for article content.</p>
          </article>
        </body>
        </html>
        """

        let readability = try Readability(html: html)
        let result = try readability.parse()
        #expect(result.byline == "By Erin Cunningham")
    }

    @Test("parse preserves figure inner div wrapper")
    func testParsePreservesFigureInnerDivWrapper() throws {
        let html = """
        <html>
        <body>
          <article>
            <figure>
              <div contenteditable="false" data-syndicationrights="false"><p><img src="https://example.com/photo.jpg"></p></div>
              <figcaption>Caption text</figcaption>
            </figure>
            <p>This is a sufficiently long paragraph, with commas, to satisfy scoring and extraction behavior.</p>
          </article>
        </body>
        </html>
        """

        let readability = try Readability(html: html)
        let result = try readability.parse()
        let doc = try SwiftSoup.parseBodyFragment(result.content)
        #expect((try doc.select("figure > div > p > img").isEmpty()) == false)
        let wrapper = try doc.select("figure > div").first()
        #expect(wrapper != nil)
        #expect((try wrapper?.attr("contenteditable")) == "false")
        #expect((try wrapper?.attr("data-syndicationrights")) == "false")
    }

    @Test("parse uses full first paragraph as excerpt fallback")
    func testParseUsesFullFirstParagraphAsExcerptFallback() throws {
        let firstParagraph = """
        Mozilla readability fallback excerpt should keep the full first paragraph text without a hard cap, even when the paragraph is much longer than two hundred characters so that metadata parity can stay aligned with expected outputs for long-form articles.
        """
        let html = """
        <html>
        <body>
          <article>
            <h1>Long Excerpt Article</h1>
            <p>\(firstParagraph)</p>
            <p>This is another paragraph.</p>
          </article>
        </body>
        </html>
        """

        let readability = try Readability(html: html)
        let result = try readability.parse()
        #expect(result.excerpt == firstParagraph)
    }

    @Test("parse prefers og article author over social handle metadata")
    func testParsePrefersOGArticleAuthorOverSocialHandle() throws {
        let html = """
        <html>
        <head>
          <meta property="og:article:author" content="BBC News">
          <meta name="twitter:creator" content="@BBCWorld">
        </head>
        <body>
          <article>
            <p>This is a sufficiently long paragraph, with commas, to satisfy scoring and extraction behavior.</p>
          </article>
        </body>
        </html>
        """

        let readability = try Readability(html: html)
        let result = try readability.parse()
        #expect(result.byline == "BBC News")
    }

    @Test("parse falls back to meta excerpt when JSON-LD excerpt is empty")
    func testParseFallsBackToMetaExcerptWhenJSONLDEmpty() throws {
        let metaDescription = "This meta description should be used when JSON-LD description is empty."
        let html = """
        <html>
        <head>
          <script type="application/ld+json">
          {"@context":"https://schema.org","@type":"NewsArticle","description":""}
          </script>
          <meta property="og:description" content="\(metaDescription)">
        </head>
        <body>
          <article>
            <p>Paragraph content for extraction.</p>
          </article>
        </body>
        </html>
        """

        let readability = try Readability(html: html)
        let result = try readability.parse()
        #expect(result.excerpt == metaDescription)
    }

    @Test("parse falls back to Firefox Nightly author link when metadata byline is absent")
    func testParseFallsBackToFirefoxNightlyAuthorLink() throws {
        let html = """
        <html>
        <head>
          <title>Firefox Nightly News</title>
          <meta property="og:site_name" content="Firefox Nightly News">
        </head>
        <body>
          <main id="content">
            <article id="post-1">
              <header>
                <a rel="author" href="https://blog.nightly.mozilla.org/author/janedoe/">Jane Doe</a>
              </header>
              <p>This is a sufficiently long paragraph, with commas, to satisfy scoring and extraction behavior.</p>
            </article>
          </main>
        </body>
        </html>
        """

        let readability = try Readability(html: html)
        let result = try readability.parse()
        #expect(result.byline == "Jane Doe")
    }

    @Test("parse normalizes mksite lead image into full-width figure")
    func testParseNormalizesMksiteLeadImageIntoFigure() throws {
        let html = """
        <html>
        <head>
          <title>5x5 Pixel font for tiny screens</title>
          <meta name="generator" content="mksite.c and my keyboard">
        </head>
        <body>
          <main>
            <h1><em>5x5 Pixel font for tiny screens</em></h1>
            <b title="Publication"><time>2026-04-18</time></b> (<a href="/tags/programming/">Programming</a>)
            <p></p>
            <img src="/projects/mcufont/demo.png" alt="Some example text in this font.">
            <center><a href="/projects/mcufont/mcufont.h">Font data (C header)</a></center>
            <p>All characters fit within a 5 pixel square, and are intended to be drawn on a 6x6 grid. The design is based off of a compact pixel font and provides enough prose, commas, and descriptive detail to survive extraction.</p>
            <p>Five by five is actually big enough to draw most lowercase letters one pixel shorter, making them visually distinct from uppercase while keeping the sample comfortably above the minimum threshold.</p>
            <p>The whole font takes up just 350 bytes of memory, which makes it suited to microcontrollers and keeps this synthetic fixture close to the original structure we want to protect.</p>
          </main>
        </body>
        </html>
        """

        let readability = try Readability(
            html: html,
            baseURL: URL(string: "https://maurycyz.com/projects/mcufont/"),
            options: ReadabilityOptions(charThreshold: 120)
        )
        let result = try readability.parse()
        let doc = try SwiftSoup.parseBodyFragment(result.content)

        guard let figure = try doc.select("div#readability-page-1.page > figure").first() else {
            Issue.record("Expected a leading figure")
            return
        }

        let img = try figure.select("> img").first()
        let figcaption = try figure.select("> figcaption").first()
        let imageStyle = (try? img?.attr("style")) ?? ""
        let captionStyle = (try? figcaption?.attr("style")) ?? ""

        #expect(img != nil)
        #expect(figcaption != nil)
        #expect((try doc.select("div#readability-page-1.page > center").isEmpty()) == true)
        #expect(imageStyle.contains("width: 100%"))
        #expect(imageStyle.contains("display: block"))
        #expect(imageStyle.contains("height: auto"))
        #expect(captionStyle.contains("text-align: center"))
        #expect((try figcaption?.select("a[href=\"https://maurycyz.com/projects/mcufont/mcufont.h\"]").isEmpty()) == false)
    }

    @Test("parse promotes readable noscript article fallback")
    func testParsePromotesReadableNoscriptFallback() throws {
        let html = """
        <html>
        <head>
          <title>Noscript Article</title>
        </head>
        <body>
          <div id="app">
            <header><a href="https://example.com">Example Site</a></header>
          </div>
          <noscript>
            <div class="container">
              <h1>Noscript Article</h1>
              <article>
                <p>First paragraph, with commas, is long enough to count as article content and should be promoted into the scoring tree for extraction.</p>
                <p>Second paragraph continues the article with enough words, commas, and narrative detail to remain a strong readability candidate after fallback promotion.</p>
                <p>Third paragraph keeps the article well above the minimum threshold, with additional descriptive prose and another comma for scoring stability.</p>
                <p>Fourth paragraph adds more substantial content so the promoted fallback is unquestionably article text rather than a short no-script notice.</p>
                <p>Fifth paragraph closes the sample article while keeping the structure semantic, readable, and obviously more meaningful than the app shell.</p>
              </article>
            </div>
          </noscript>
        </body>
        </html>
        """

        let readability = try Readability(html: html, baseURL: URL(string: "https://example.com/article"))
        let result = try readability.parse()

        #expect(result.title == "Noscript Article")
        #expect(result.textContent.contains("First paragraph, with commas"))
        #expect(result.textContent.contains("Fifth paragraph closes the sample article"))
        #expect(!result.textContent.contains("Example Site"))
    }

    @Test("parse ignores non-article noscript warning blocks")
    func testParseIgnoresNonArticleNoscriptWarnings() throws {
        let html = """
        <html>
        <head>
          <title>Live Article</title>
        </head>
        <body>
          <article>
            <p>Live paragraph one, with commas, provides the main article content and should remain the extracted result.</p>
            <p>Live paragraph two continues with enough text, commas, and ordinary prose to keep the visible article comfortably above threshold.</p>
            <p>Live paragraph three ensures the document stays readable without relying on any noscript fallback or warning content.</p>
            <p>Live paragraph four adds extra detail so the visible article is the strongest candidate in the document.</p>
            <p>Live paragraph five wraps up the sample article and confirms extraction stays on the live DOM tree.</p>
          </article>
          <noscript>
            <div>
              <p>Please enable JavaScript to use this site fully.</p>
              <p>For full functionality, it is necessary to enable JavaScript.</p>
              <p>This modern browser notice should never be promoted into article extraction.</p>
              <p>Enable JavaScript to continue browsing these interactive features.</p>
              <p>This warning intentionally contains many words, commas, and paragraphs, but no semantic article container.</p>
            </div>
          </noscript>
        </body>
        </html>
        """

        let readability = try Readability(html: html, baseURL: URL(string: "https://example.com/live"))
        let result = try readability.parse()

        #expect(result.title == "Live Article")
        #expect(result.textContent.contains("Live paragraph one"))
        #expect(!result.textContent.contains("Please enable JavaScript"))
        #expect(!result.textContent.contains("full functionality"))
    }
}
