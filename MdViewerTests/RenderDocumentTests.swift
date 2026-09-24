import Testing
@testable import MdViewerCore

@Suite("RenderDocument use case")
struct RenderDocumentTests {
    private struct StubRenderer: MarkdownRenderer {
        func render(_ markdown: String) -> RenderedDocument {
            RenderedDocument(html: "<p>\(markdown)</p>", headings: [Heading(level: 1, text: "T", slug: "t")])
        }
    }

    @Test func delegatesToTheRendererPort() {
        let useCase = RenderDocument(renderer: StubRenderer())

        let result = useCase.execute(MarkdownDocument(source: "hello", title: "doc.md"))

        #expect(result == RenderedDocument(html: "<p>hello</p>", headings: [Heading(level: 1, text: "T", slug: "t")]))
    }

    @Test func rendersRealMarkdownEndToEnd() {
        let useCase = RenderDocument(renderer: SwiftMarkdownRenderer())

        let result = useCase.execute(MarkdownDocument(source: "# Title\n\nBody", title: "doc.md"))

        #expect(result.headings.map(\.slug) == ["title"])
        #expect(result.html.contains("<p>Body</p>"))
    }
}

@Suite("Slugifier")
struct SlugifierTests {
    @Test(arguments: [
        ("Hello World", "hello-world"),
        ("C++ & Swift: 2024!", "c--swift-2024"),
        ("Ünïcödé Title", "ünïcödé-title"),
    ])
    func slugs(input: String, expected: String) {
        #expect(Slugifier.slug(for: input) == expected)
    }

    @Test func duplicatesAreNumbered() {
        var slugifier = Slugifier()
        #expect(slugifier.uniqueSlug(for: "A") == "a")
        #expect(slugifier.uniqueSlug(for: "A") == "a-1")
        #expect(slugifier.uniqueSlug(for: "A") == "a-2")
        #expect(slugifier.uniqueSlug(for: "A-1") == "a-1-1")
    }
}
