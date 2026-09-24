import Foundation

/// One row of the document outline.
public struct OutlineEntry: Equatable, Hashable, Identifiable, Sendable {
    public let heading: Heading
    /// Indentation depth, relative to the shallowest heading in the document (0-based).
    public let indent: Int

    public var id: String { heading.slug }

    public init(heading: Heading, indent: Int) {
        self.heading = heading
        self.indent = indent
    }
}

/// Builds the document outline from its headings.
public enum TableOfContents {
    /// Maps headings to outline entries, indenting each relative to the minimum level present.
    ///
    /// A document whose headings start at `##` gets its `##` entries at indent 0.
    public static func entries(from headings: [Heading]) -> [OutlineEntry] {
        guard let minLevel = headings.map(\.level).min() else { return [] }
        return headings.map { OutlineEntry(heading: $0, indent: $0.level - minLevel) }
    }
}
