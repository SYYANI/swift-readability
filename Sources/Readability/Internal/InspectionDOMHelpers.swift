import Foundation
import SwiftSoup

enum InspectionDOMHelpers {
    static func elementDescriptor(_ element: Element) -> String {
        let tag = element.tagName().lowercased()
        let id = element.id()
        let firstClass = ((try? element.className()) ?? "")
            .split(separator: " ").first.map(String.init) ?? ""
        var desc = tag
        if !id.isEmpty {
            desc += "#\(id)"
        } else if !firstClass.isEmpty {
            desc += ".\(firstClass)"
        }
        return desc
    }

    static func elementDepth(_ element: Element) -> Int {
        var depth = 0
        var current: Element? = element.parent()
        while let parent = current {
            depth += 1
            current = parent.parent()
        }
        return depth
    }

    static func nodePath(_ node: Node) -> String {
        var parts: [String] = []
        var current: Node? = node

        while let n = current {
            if let element = n as? Element {
                let tag = element.tagName().lowercased()
                var position = 1
                if let parent = element.parent() {
                    for sibling in parent.getChildNodes() {
                        guard sibling !== element else { break }
                        if let siblingElement = sibling as? Element,
                           siblingElement.tagName().lowercased() == tag {
                            position += 1
                        }
                    }
                }
                parts.append("\(tag)[\(position)]")
            } else if n is TextNode {
                parts.append("text()")
            } else {
                parts.append(n.nodeName())
            }
            current = n.parent()
        }

        return "/" + parts.reversed().joined(separator: "/")
    }
}