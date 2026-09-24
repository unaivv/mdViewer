import Testing
@testable import MdViewer

@Suite("TableOfContents")
struct TableOfContentsTests {
    @Test func emptyHeadingsProduceEmptyOutline() {
        #expect(TableOfContents.entries(from: []).isEmpty)
    }

    @Test func indentIsRelativeToShallowestLevel() {
        let headings = [
            Heading(level: 2, text: "Intro", slug: "intro"),
            Heading(level: 3, text: "Detail", slug: "detail"),
            Heading(level: 4, text: "Deep", slug: "deep"),
            Heading(level: 2, text: "Next", slug: "next"),
        ]

        let entries = TableOfContents.entries(from: headings)

        #expect(entries.map(\.indent) == [0, 1, 2, 0])
        #expect(entries.map(\.heading) == headings)
        #expect(entries.map(\.id) == ["intro", "detail", "deep", "next"])
    }

    @Test func skippedLevelsKeepAbsoluteDistance() {
        let entries = TableOfContents.entries(from: [
            Heading(level: 1, text: "Title", slug: "title"),
            Heading(level: 3, text: "Skipped", slug: "skipped"),
        ])

        #expect(entries.map(\.indent) == [0, 2])
    }

    @Test func worksWithRealRenderedHeadings() {
        let rendered = SwiftMarkdownRenderer().render("### A\n\n#### B\n\n### C\n")

        #expect(TableOfContents.entries(from: rendered.headings).map(\.indent) == [0, 1, 0])
    }
}
