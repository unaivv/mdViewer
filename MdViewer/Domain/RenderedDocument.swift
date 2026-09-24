import Foundation

/// The result of rendering a Markdown document: an HTML body fragment plus its headings.
public struct RenderedDocument: Equatable, Sendable {
    public let html: String
    public let headings: [Heading]

    public init(html: String, headings: [Heading]) {
        self.html = html
        self.headings = headings
    }
}
