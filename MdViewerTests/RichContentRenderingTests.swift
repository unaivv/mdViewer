import Testing
@testable import MdViewer

@Suite("Math and diagram rendering")
struct RichContentRenderingTests {
    private let renderer = SwiftMarkdownRenderer()

    @Test func inlineMathBecomesSpanWithEscapedTeX() {
        let result = renderer.render(#"Value $a < b \\ c_1*d*$ end"#)

        #expect(result.html.contains(#"<span class="math math-inline">a &lt; b \\ c_1*d*</span>"#))
        #expect(result.features.containsMath)
        #expect(!result.features.containsMermaid)
    }

    @Test func displayMathParagraph() {
        let result = renderer.render("$$\n\\frac{1}{2}\n$$\n")

        #expect(result.html.contains(#"<p><span class="math math-display">\frac{1}{2}</span></p>"#))
    }

    @Test func mathFencedBlockBecomesDisplayDiv() {
        let result = renderer.render("```math\nx^2 + y^2 = z^2\n```\n")

        #expect(result.html.contains(#"<div class="math math-display">x^2 + y^2 = z^2</div>"#))
        #expect(result.features.containsMath)
    }

    @Test func mermaidFencedBlockBecomesPreMermaid() {
        let result = renderer.render("```mermaid\ngraph TD\n  A-->B\n```\n")

        #expect(result.html.contains("<pre class=\"mermaid\">graph TD\n  A--&gt;B\n</pre>"))
        #expect(result.features.containsMermaid)
        #expect(!result.features.containsMath)
    }

    @Test func mathInsideCodeIsNotRendered() {
        let result = renderer.render("Run `echo $x$` now.\n\n```\n$y$\n```\n")

        #expect(result.html.contains("<code>echo $x$</code>"))
        #expect(result.html.contains("<pre><code>$y$\n</code></pre>"))
        #expect(!result.features.containsMath)
    }

    @Test func proseDollarsStayText() {
        let result = renderer.render("It costs $5 and $10.")

        #expect(result.html.contains("<p>It costs $5 and $10.</p>"))
        #expect(!result.features.containsMath)
    }

    @Test func headingWithMathUsesSourceForSlugAndOutline() {
        let result = renderer.render("## Euler $e^{i\\pi}$\n")

        #expect(result.headings.first?.text == "Euler $e^{i\\pi}$")
        #expect(result.headings.first?.slug == "euler-eipi")
        #expect(result.html.contains(#"<span class="math math-inline">e^{i\pi}</span>"#))
    }

    @Test func plainDocumentNeedsNoRichFeatures() {
        #expect(renderer.render("# Title\n\n```swift\nlet x = 1\n```").features == DocumentFeatures())
    }
}

@Suite("HTMLPageTemplate")
struct HTMLPageTemplateTests {
    private let template = HTMLPageTemplate()

    @Test func includesBodyEscapedTitleAndBaseAssets() {
        let page = template.page(title: "a<b>.md", body: "<p>x</p>", features: DocumentFeatures())

        #expect(page.contains("<title>a&lt;b&gt;.md</title>"))
        #expect(page.contains("<p>x</p>"))
        #expect(page.contains(#"href="mdviewer-resource://web/themes.css""#))
        #expect(page.contains(#"href="mdviewer-resource://web/markdown.css""#))
        #expect(page.contains(#"<script src="mdviewer-resource://web/highlight/highlight.min.js"></script>"#))
        #expect(page.contains(#"<script src="mdviewer-resource://web/viewer.js"></script>"#))
        #expect(!page.contains("https://"))
    }

    @Test func heavyLibrariesAreOnlyIncludedWhenNeeded() {
        let plain = template.page(title: "t", body: "", features: DocumentFeatures())
        let math = template.page(title: "t", body: "", features: DocumentFeatures(containsMath: true))
        let diagrams = template.page(title: "t", body: "", features: DocumentFeatures(containsMermaid: true))

        #expect(!plain.contains("katex") && !plain.contains("mermaid"))
        #expect(math.contains("katex/katex.min.js") && math.contains("katex/katex.min.css"))
        #expect(!math.contains("mermaid"))
        #expect(diagrams.contains("mermaid/mermaid.min.js"))
        #expect(!diagrams.contains("katex"))
    }

    @Test func viewerScriptLoadsAfterLibraries() throws {
        let page = template.page(title: "t", body: "", features: DocumentFeatures(containsMath: true, containsMermaid: true))

        let viewer = try #require(page.range(of: "viewer.js"))
        let katex = try #require(page.range(of: "katex.min.js"))
        let mermaid = try #require(page.range(of: "mermaid.min.js"))
        #expect(katex.upperBound < viewer.lowerBound)
        #expect(mermaid.upperBound < viewer.lowerBound)
    }
}
