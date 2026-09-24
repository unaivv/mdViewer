import Testing
@testable import MdViewerCore

@Suite("SwiftMarkdownRenderer")
struct SwiftMarkdownRendererTests {
    private let renderer = SwiftMarkdownRenderer()

    @Test func headingsGetSlugIDsAndAreCollected() {
        let result = renderer.render("# Hello World\n\n## Getting *Started*!\n\n### Hello World\n")

        #expect(result.html.contains(#"<h1 id="hello-world">Hello World</h1>"#))
        #expect(result.html.contains(#"<h2 id="getting-started">Getting <em>Started</em>!</h2>"#))
        #expect(result.html.contains(#"<h3 id="hello-world-1">Hello World</h3>"#))
        #expect(result.headings == [
            Heading(level: 1, text: "Hello World", slug: "hello-world"),
            Heading(level: 2, text: "Getting Started!", slug: "getting-started"),
            Heading(level: 3, text: "Hello World", slug: "hello-world-1"),
        ])
    }

    @Test func tablesRenderWithAlignment() {
        let markdown = """
        | Left | Center | Right |
        | :--- | :----: | ----: |
        | a    | b      | c     |
        """
        let html = renderer.render(markdown).html

        #expect(html.contains("<table>"))
        #expect(html.contains("<thead>"))
        #expect(html.contains(#"<th style="text-align: left">Left</th>"#))
        #expect(html.contains(#"<th style="text-align: center">Center</th>"#))
        #expect(html.contains(#"<td style="text-align: right">c</td>"#))
        #expect(html.contains("<tbody>"))
    }

    @Test func taskListsRenderDisabledCheckboxes() {
        let html = renderer.render("- [x] done\n- [ ] todo\n").html

        #expect(html.contains(#"<ul class="contains-task-list">"#))
        #expect(html.contains(#"<li class="task-list-item"><input type="checkbox" disabled checked /> done</li>"#))
        #expect(html.contains(#"<li class="task-list-item"><input type="checkbox" disabled /> todo</li>"#))
    }

    @Test func codeBlocksCarryLanguageClassAndEscapeContent() {
        let html = renderer.render("```swift\nlet a = b < c && d > e\n```\n").html

        #expect(html.contains(#"<pre><code class="language-swift">let a = b &lt; c &amp;&amp; d &gt; e"#))
    }

    @Test func codeBlocksWithoutLanguageHaveNoClass() {
        let html = renderer.render("```\nplain\n```\n").html

        #expect(html.contains("<pre><code>plain\n</code></pre>"))
    }

    @Test func textAndAttributesAreEscaped() {
        let html = renderer.render(#"5 < 6 & "quotes" [x](https://e.com/?a=1&b="2")"#).html

        #expect(html.contains("5 &lt; 6 &amp; &quot;quotes&quot;"))
        #expect(html.contains(#"href="https://e.com/?a=1&amp;b=%222%22""#) || html.contains(#"href="https://e.com/?a=1&amp;b=&quot;2&quot;""#))
        #expect(!html.contains("<6"))
    }

    @Test func inlineCodeIsEscaped() {
        let html = renderer.render("Use `<div>` here").html

        #expect(html.contains("<code>&lt;div&gt;</code>"))
    }

    @Test func strikethroughRendersDel() {
        let html = renderer.render("~~gone~~").html

        #expect(html.contains("<del>gone</del>"))
    }

    @Test func emphasisStrongLinksAndImages() {
        let html = renderer.render(#"*a* **b** [link](https://x.dev "T") ![alt](img.png)"#).html

        #expect(html.contains("<em>a</em>"))
        #expect(html.contains("<strong>b</strong>"))
        #expect(html.contains(#"<a href="https://x.dev" title="T">link</a>"#))
        #expect(html.contains(#"<img src="img.png" alt="alt" />"#))
    }

    @Test func rawHTMLPassesThrough() {
        let html = renderer.render("<div class=\"note\">hi</div>\n\nText with <kbd>K</kbd>.").html

        #expect(html.contains(#"<div class="note">hi</div>"#))
        #expect(html.contains("<kbd>K</kbd>"))
    }

    @Test func listsBlockQuotesAndBreaks() {
        let markdown = """
        3. three
        4. four

        > quoted

        ---

        line one\\
        line two
        """
        let html = renderer.render(markdown).html

        #expect(html.contains(#"<ol start="3">"#))
        #expect(html.contains("<li>three</li>"))
        #expect(html.contains("<blockquote>\n<p>quoted</p>\n</blockquote>"))
        #expect(html.contains("<hr />"))
        #expect(html.contains("line one<br />\nline two"))
    }
}
