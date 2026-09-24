import Foundation

/// A Markdown document as understood by the domain: its raw source and a display title.
public struct MarkdownDocument: Equatable, Sendable {
    public let source: String
    public let title: String

    public init(source: String, title: String) {
        self.source = source
        self.title = title
    }
}
