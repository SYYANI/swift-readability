import Foundation
import SwiftSoup

/// Removes arXiv/LaTeXML front-matter noise that can leak into extracted article content.
///
/// SiteRule Metadata:
/// - Scope: arXiv LaTeXML paper shell before the first numbered section
/// - Phase: `unwanted` cleanup
/// - Trigger: `article.ltx_document` with `.ltx_abstract`, `.ltx_TOC`, and `.ltx_page_content`
/// - Evidence: `https://arxiv.org/html/2412.19437v2`
/// - Risk if misplaced: front-matter commands, generated TOC, and hero summary figure remain above the main text
enum ArXivLaTeXMLFrontMatterRule: ArticleCleanerSiteRule {
    static let id = "arxiv-latexml-front-matter"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        guard containsLaTeXMLPaperShell(articleContent) else { return }

        try removeArXivPageChrome(from: articleContent)

        for article in try articleContent.select("article.ltx_document").array() {
            guard isLaTeXMLArticle(article) else { continue }
            try removeLeadingFrontMatter(from: article)
        }
    }

    private static func containsLaTeXMLPaperShell(_ articleContent: Element) -> Bool {
        (try? articleContent.select("article.ltx_document").isEmpty()) == false &&
        (try? articleContent.select(".ltx_page_content").isEmpty()) == false
    }

    private static func removeArXivPageChrome(from articleContent: Element) throws {
        for header in try articleContent.select("header.desktop_header").array() {
            if isArXivDesktopHeader(header) {
                try header.remove()
            }
        }
    }

    private static func isArXivDesktopHeader(_ header: Element) -> Bool {
        let hasLogoLink = (try? header.select(".html-header-logo a[href='https://arxiv.org/']").isEmpty()) == false
        let hasProjectLink = (try? header.select(".html-header-message a[href*='accessible_HTML']").isEmpty()) == false
        let hasNavLink = (try? header.select(".html-header-nav a[href*='arxiv.org/abs/'], .html-header-nav a[href*='arxiv.org/pdf/']").isEmpty()) == false
        return hasLogoLink && (hasProjectLink || hasNavLink)
    }

    private static func isLaTeXMLArticle(_ article: Element) -> Bool {
        guard let parent = article.parent(),
              parent.tagName().lowercased() == "div" else {
            return false
        }

        let parentClass = ((try? parent.className()) ?? "").lowercased()
        guard parentClass.contains("ltx_page_content") else {
            return false
        }

        let hasAbstract = (try? article.select("> div.ltx_abstract").isEmpty()) == false
        let hasTOC = (try? article.select("> nav.ltx_TOC.ltx_toc_toc").isEmpty()) == false
        return hasAbstract && hasTOC
    }

    private static func removeLeadingFrontMatter(from article: Element) throws {
        let children = article.children().array()
        guard let firstSectionIndex = children.firstIndex(where: isPrimarySection) else {
            return
        }

        for child in children[..<firstSectionIndex].reversed() {
            if shouldRemoveLeadingNode(child) {
                try child.remove()
            }
        }
    }

    private static func isPrimarySection(_ element: Element) -> Bool {
        guard element.tagName().lowercased() == "section" else {
            return false
        }
        let id = element.id().trimmingCharacters(in: .whitespacesAndNewlines)
        return id.range(of: #"^S\d+$"#, options: .regularExpression) != nil
    }

    private static func shouldRemoveLeadingNode(_ element: Element) -> Bool {
        let tag = element.tagName().lowercased()
        let id = element.id().trimmingCharacters(in: .whitespacesAndNewlines)
        let className = ((try? element.className()) ?? "").lowercased()
        let text = normalizedText(element)

        if tag == "nav", className.contains("ltx_toc"), className.contains("ltx_toc_toc") {
            return true
        }

        if tag == "div", className.contains("ltx_pagination"), className.contains("ltx_role_newpage") {
            return true
        }

        if tag == "figure", id.hasPrefix("S0.") {
            return true
        }

        if tag == "div", className.contains("ltx_para"), hasFrontMatterErrorMarker(element) {
            return true
        }

        if text.contains("\\reportnumber") || text.contains("{cjk*}") || text.contains("utf8gbsn") {
            return true
        }

        return false
    }

    private static func hasFrontMatterErrorMarker(_ element: Element) -> Bool {
        let markers = (try? element.select("span.ltx_ERROR.undefined").array()) ?? []
        guard !markers.isEmpty else { return false }
        let markerText = markers
            .compactMap { try? $0.text().lowercased() }
            .joined(separator: " ")
        return markerText.contains("\\reportnumber") || markerText.contains("{cjk*}")
    }

    private static func normalizedText(_ element: Element) -> String {
        ((try? DOMHelpers.getInnerText(element)) ?? "")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
