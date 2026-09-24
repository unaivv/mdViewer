import Foundation

/// Optional rich features a document uses, so the page only loads what it needs.
public struct DocumentFeatures: Equatable, Sendable {
    public var containsMath: Bool
    public var containsMermaid: Bool

    public init(containsMath: Bool = false, containsMermaid: Bool = false) {
        self.containsMath = containsMath
        self.containsMermaid = containsMermaid
    }
}

/// The result of rendering a Markdown document: an HTML body fragment, its headings
/// and the rich features it uses.
public struct RenderedDocument: Equatable, Sendable {
    public let html: String
    public let headings: [Heading]
    public let features: DocumentFeatures

    public init(html: String, headings: [Heading], features: DocumentFeatures = DocumentFeatures()) {
        self.html = html
        self.headings = headings
        self.features = features
    }
}
