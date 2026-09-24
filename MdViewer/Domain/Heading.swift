import Foundation

/// A heading found in a rendered document, usable for anchors and outlines.
public struct Heading: Equatable, Hashable, Sendable {
    public let level: Int
    public let text: String
    public let slug: String

    public init(level: Int, text: String, slug: String) {
        self.level = level
        self.text = text
        self.slug = slug
    }
}
