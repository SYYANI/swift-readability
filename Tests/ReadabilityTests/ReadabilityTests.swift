import Testing
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

    @Test("parse removes arXiv LaTeXML front matter before first section")
    func testParseRemovesArXivLaTeXMLFrontMatter() throws {
        let introParagraph = Array(repeating: "This introduction paragraph contains enough text, commas, and detail to behave like real article content.", count: 8)
            .joined(separator: " ")
        let html = """
        <html>
        <head>
          <title>Sample Technical Report</title>
        </head>
        <body>
          <div class="ltx_page_main">
            <header class="desktop_header">
              <div class="html-header-logo">
                <a href="https://arxiv.org/">
                  <img alt="logo" class="logo" src="https://services.dev.arxiv.org/html/static/arxiv-logo-one-color-white.svg">
                  <span class="sr-only">Back to arXiv</span>
                </a>
              </div>
              <div class="html-header-message" role="banner">
                <p>This is <strong>experimental HTML</strong>. Learn more <a href="https://info.arxiv.org/about/accessible_HTML.html">about this project</a>.</p>
              </div>
              <nav class="html-header-nav">
                <a class="ar5iv-footer-button hover-effect" href="https://arxiv.org/abs/1234.5678">Back to Abstract</a>
                <a class="ar5iv-footer-button hover-effect" href="https://arxiv.org/pdf/1234.5678">Download PDF</a>
              </nav>
            </header>
            <div class="ltx_page_content">
              <article class="ltx_document ltx_authors_1line">
                <div class="ltx_para" id="p1">
                  <span class="ltx_ERROR undefined" id="p1.1">\\reportnumber</span>
                  <p class="ltx_p" id="p1.2">001</p>
                </div>
                <div class="ltx_abstract">
                  <h6 class="ltx_title ltx_title_abstract">Abstract</h6>
                  <p class="ltx_p" id="abs">This abstract should remain in the extracted output because it is part of the readable paper content and provides a concise summary of the work.</p>
                </div>
                <div class="ltx_para" id="p2">
                  <span class="ltx_ERROR undefined" id="p2.1" lang="en">{CJK*}</span>
                  <p class="ltx_p" id="p2.2"><span class="ltx_text" id="p2.2.1" lang="en">UTF8gbsn</span></p>
                </div>
                <figure class="ltx_figure" id="S0.F1" lang="en">
                  <img alt="Refer to caption" class="ltx_graphics ltx_img_landscape" height="485" id="S0.F1.g1" src="https://example.com/x1.png" width="830"/>
                  <figcaption class="ltx_caption"><span class="ltx_tag ltx_tag_figure">Figure 1: </span>Benchmark summary figure.</figcaption>
                </figure>
                <div class="ltx_pagination ltx_role_newpage"></div>
                <nav class="ltx_TOC ltx_list_toc ltx_toc_toc" lang="en">
                  <h6 class="ltx_title ltx_title_contents">Contents</h6>
                  <ol class="ltx_toclist">
                    <li class="ltx_tocentry ltx_tocentry_section"><a class="ltx_ref" href="#S1"><span class="ltx_text ltx_ref_title"><span class="ltx_tag ltx_tag_ref">1 </span>Introduction</span></a></li>
                  </ol>
                </nav>
                <section id="S1" lang="en">
                  <h2 class="ltx_title ltx_title_section"><span class="ltx_tag ltx_tag_section">1 </span>Introduction</h2>
                  <p class="ltx_p" id="S1.p1.1">\(introParagraph)</p>
                </section>
              </article>
            </div>
          </div>
        </body>
        </html>
        """

        let readability = try Readability(html: html)
        let result = try readability.parse()

        #expect(result.title == "Sample Technical Report")
        #expect(result.content.contains("Abstract"))
        #expect(result.content.contains("Introduction"))
        #expect(!result.content.contains("\\reportnumber"))
        #expect(!result.content.contains("{CJK*}"))
        #expect(!result.content.contains("UTF8gbsn"))
        #expect(!result.content.contains("Contents"))
        #expect(!result.content.contains("Back to arXiv"))
        #expect(!result.content.contains("Back to Abstract"))
        #expect(!result.content.contains("Download PDF"))
        #expect(!result.content.contains("experimental HTML"))
        #expect(!result.content.contains("S0.F1.g1"))
        #expect(!result.content.contains("Benchmark summary figure"))
    }
}
