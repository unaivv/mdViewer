import Foundation

/// Port: converts Markdown source into an HTML fragment and its headings.
public protocol MarkdownRenderer: Sendable {
    func render(_ markdown: String) -> RenderedDocument
}
