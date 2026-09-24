import Foundation

/// Use case: render a Markdown document into HTML plus its heading outline.
public struct RenderDocument: Sendable {
    private let renderer: any MarkdownRenderer

    public init(renderer: any MarkdownRenderer) {
        self.renderer = renderer
    }

    public func execute(_ document: MarkdownDocument) -> RenderedDocument {
        renderer.render(document.source)
    }
}
