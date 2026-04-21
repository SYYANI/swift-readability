import Foundation
import SwiftSoup
@testable import Readability

/// DOM comparison utility for Mozilla compatibility assertions.
enum DOMComparator {
    /// Compare two DOM structures and return detailed diff.
    /// Mirrors Mozilla-style structural traversal:
    /// - In-order node traversal
    /// - Ignore empty text nodes
    /// - Compare node descriptors, text content, and attributes
    static func compare(_ actualHTML: String, _ expectedHTML: String) -> (isEqual: Bool, diff: String) {
        do {
            let actualDoc = try SwiftSoup.parse(actualHTML)
            let expectedDoc = try SwiftSoup.parse(expectedHTML)

            guard let actualRoot = domRoot(actualDoc),
                  let expectedRoot = domRoot(expectedDoc) else {
                return (false, "DOM comparison error: missing root node")
            }

            let actualNodes = flattenedDOMNodes(from: actualRoot)
            let expectedNodes = flattenedDOMNodes(from: expectedRoot)

            let maxCount = max(actualNodes.count, expectedNodes.count)
            for index in 0..<maxCount {
                guard index < actualNodes.count, index < expectedNodes.count else {
                    let actualTail = actualNodes.suffix(3).map { "\(DOMDebugFormatting.structuralNodeDescription($0)) @ \(DOMDebugFormatting.nodePath($0))" }.joined(separator: " | ")
                    let expectedTail = expectedNodes.suffix(3).map { "\(DOMDebugFormatting.structuralNodeDescription($0)) @ \(DOMDebugFormatting.nodePath($0))" }.joined(separator: " | ")
                    return (
                        false,
                        "DOM node count mismatch at index \(index). Expected \(expectedNodes.count) nodes, got \(actualNodes.count) nodes. Expected tail: \(expectedTail). Actual tail: \(actualTail)."
                    )
                }

                let actualNode = actualNodes[index]
                let expectedNode = expectedNodes[index]

                let actualDesc = DOMDebugFormatting.structuralNodeDescription(actualNode)
                let expectedDesc = DOMDebugFormatting.structuralNodeDescription(expectedNode)
                if actualDesc != expectedDesc {
                    let actualPath = DOMDebugFormatting.nodePath(actualNode)
                    let expectedPath = DOMDebugFormatting.nodePath(expectedNode)
                    if let actualTextNode = actualNode as? TextNode,
                       let expectedTextNode = expectedNode as? TextNode {
                        let actualContext = (actualTextNode.parent() as? Element).flatMap { try? $0.outerHtml() } ?? ""
                        let expectedContext = (expectedTextNode.parent() as? Element).flatMap { try? $0.outerHtml() } ?? ""
                        return (
                            false,
                            "Node descriptor mismatch at index \(index). Expected: \(expectedDesc), Actual: \(actualDesc). Expected path: \(expectedPath). Actual path: \(actualPath). Expected context: '\(preview(expectedContext, limit: 220))'. Actual context: '\(preview(actualContext, limit: 220))'."
                        )
                    }
                    let actualContext = (actualNode as? Element).flatMap { try? $0.outerHtml() } ?? ""
                    let expectedContext = (expectedNode as? Element).flatMap { try? $0.outerHtml() } ?? ""
                    return (
                        false,
                        "Node descriptor mismatch at index \(index). Expected: \(expectedDesc), Actual: \(actualDesc). Expected path: \(expectedPath). Actual path: \(actualPath). Expected context: '\(preview(expectedContext, limit: 220))'. Actual context: '\(preview(actualContext, limit: 220))'."
                    )
                }

                if let actualTextNode = actualNode as? TextNode,
                   let expectedTextNode = expectedNode as? TextNode {
                    let actualText = comparableText(for: actualTextNode)
                    let expectedText = comparableText(for: expectedTextNode)
                    if actualText != expectedText {
                        let actualContext = (actualTextNode.parent() as? Element).flatMap { try? $0.outerHtml() } ?? ""
                        let expectedContext = (expectedTextNode.parent() as? Element).flatMap { try? $0.outerHtml() } ?? ""
                        let preservesWhitespace = preservesWhitespace(actualTextNode) || preservesWhitespace(expectedTextNode)
                        let expectedPreview = preservesWhitespace ? visibleWhitespace(expectedText) : expectedText
                        let actualPreview = preservesWhitespace ? visibleWhitespace(actualText) : actualText
                        return (
                            false,
                            "Text mismatch at index \(index). Expected: '\(preview(expectedPreview))', Actual: '\(preview(actualPreview))'. Expected context: '\(preview(expectedContext, limit: 220))'. Actual context: '\(preview(actualContext, limit: 220))'."
                        )
                    }
                } else if let actualElement = actualNode as? Element,
                          let expectedElement = expectedNode as? Element {
                    let actualAttrs = attributesForNode(actualElement)
                    let expectedAttrs = attributesForNode(expectedElement)
                    if actualAttrs.count != expectedAttrs.count {
                        let actualPath = DOMDebugFormatting.nodePath(actualElement)
                        let expectedPath = DOMDebugFormatting.nodePath(expectedElement)
                        return (
                            false,
                            "Attribute count mismatch at index \(index) for \(actualElement.tagName().lowercased()). Expected \(expectedAttrs.count), got \(actualAttrs.count). Expected attrs: \(expectedAttrs), Actual attrs: \(actualAttrs). Expected path: \(expectedPath). Actual path: \(actualPath)."
                        )
                    }
                    for (key, expectedValue) in expectedAttrs {
                        guard let actualValue = actualAttrs[key] else {
                            let actualPath = DOMDebugFormatting.nodePath(actualElement)
                            let expectedPath = DOMDebugFormatting.nodePath(expectedElement)
                            return (
                                false,
                                "Missing attribute at index \(index): '\(key)' on \(actualElement.tagName().lowercased()). Expected path: \(expectedPath). Actual path: \(actualPath)."
                            )
                        }
                        if actualValue != expectedValue {
                            let actualPath = DOMDebugFormatting.nodePath(actualElement)
                            let expectedPath = DOMDebugFormatting.nodePath(expectedElement)
                            return (
                                false,
                                "Attribute mismatch at index \(index): '\(key)'. Expected '\(preview(expectedValue))', got '\(preview(actualValue))'. Expected path: \(expectedPath). Actual path: \(actualPath)."
                            )
                        }
                    }
                }
            }

            return (true, "DOM structures match")
        } catch {
            return (false, "DOM comparison error: \(error)")
        }
    }

    private static func normalizeHTMLText(_ str: String) -> String {
        return str
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func comparableText(for textNode: TextNode) -> String {
        let text = normalizeLineEndings(textNode.getWholeText())
        if preservesWhitespace(textNode) {
            return text
        }
        return normalizeHTMLText(text)
    }

    private static func normalizeLineEndings(_ str: String) -> String {
        str
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private static func domRoot(_ doc: Document) -> Node? {
        if let root = doc.children().first {
            return root
        }
        if let body = doc.body() {
            return body
        }
        return nil
    }

    private static func flattenedDOMNodes(from root: Node) -> [Node] {
        var nodes: [Node] = []
        collectNodesInOrder(root, into: &nodes)
        return nodes.filter { !isIgnorableTextNode($0) }
    }

    private static func collectNodesInOrder(_ node: Node, into nodes: inout [Node]) {
        nodes.append(node)
        for child in node.getChildNodes() {
            collectNodesInOrder(child, into: &nodes)
        }
    }

    private static func isIgnorableTextNode(_ node: Node) -> Bool {
        guard let textNode = node as? TextNode else { return false }
        if preservesWhitespace(textNode) {
            return false
        }
        return textNode.getWholeText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func preservesWhitespace(_ node: Node) -> Bool {
        var current = node.parent()
        while let element = current as? Element {
            if preservesWhitespace(tagName: element.tagName()) {
                return true
            }
            current = element.parent()
        }
        return false
    }

    private static func preservesWhitespace(tagName: String) -> Bool {
        switch tagName.lowercased() {
        case "pre", "textarea":
            return true
        default:
            return false
        }
    }

    private static func attributesForNode(_ element: Element) -> [String: String] {
        var attrs: [String: String] = [:]
        guard let attributes = element.getAttributes() else { return attrs }

        for attr in attributes {
            let key = attr.getKey()
            if isValidXMLAttributeName(key) {
                attrs[key] = normalizedAttributeValue(attr.getValue(), forKey: key)
            }
        }
        return attrs
    }

    private static func normalizedAttributeValue(_ value: String, forKey key: String) -> String {
        if htmlBooleanAttributeNames.contains(key.lowercased()) {
            return ""
        }
        return value
    }

    private static let htmlBooleanAttributeNames: Set<String> = [
        "allowfullscreen",
        "async",
        "autofocus",
        "autoplay",
        "checked",
        "controls",
        "default",
        "defer",
        "disabled",
        "formnovalidate",
        "hidden",
        "inert",
        "ismap",
        "itemscope",
        "loop",
        "multiple",
        "muted",
        "nomodule",
        "novalidate",
        "open",
        "playsinline",
        "readonly",
        "required",
        "reversed",
        "selected"
    ]

    private static func isValidXMLAttributeName(_ name: String) -> Bool {
        let pattern = "^[A-Za-z_][A-Za-z0-9._:-]*$"
        return name.range(of: pattern, options: .regularExpression) != nil
    }

    private static func preview(_ text: String, limit: Int = 80) -> String {
        if text.count <= limit { return text }
        return String(text.prefix(limit)) + "..."
    }

    private static func visibleWhitespace(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: " ", with: "·")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

}
