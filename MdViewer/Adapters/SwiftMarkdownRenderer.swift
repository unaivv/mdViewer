import Foundation
import Markdown

/// Adapter: renders Markdown to HTML using Apple's `swift-markdown` (cmark-gfm) parser.
///
/// swift-markdown ships an `HTMLFormatter`, but it cannot emit heading `id` attributes,
/// so we walk the AST ourselves with a `MarkupVisitor`. TeX math is protected from the
/// parser by `MathPreprocessor` and emitted as `.math` elements for KaTeX; ```` ```mermaid ````
/// blocks are emitted as `pre.mermaid` for Mermaid.
public struct SwiftMarkdownRenderer: MarkdownRenderer {
    public init() {}

    public func render(_ markdown: String) -> RenderedDocument {
        // Smart punctuation is disabled to match GitHub rendering.
        let math = MathPreprocessor.process(markdown)
        let document = Document(parsing: math.markdown, options: [.disableSmartOpts])
        var visitor = HTMLVisitor(mathSpans: math.spans)
        visitor.visit(document)
        return RenderedDocument(html: visitor.html, headings: visitor.headings, features: visitor.features)
    }
}

// MARK: - HTML visitor

private struct HTMLVisitor: MarkupVisitor {
    typealias Result = Void

    private(set) var html = ""
    private(set) var headings: [Heading] = []
    private(set) var features = DocumentFeatures()
    private let mathSpans: [MathPreprocessor.Span]
    private var slugifier = Slugifier()
    /// Whether paragraphs should be rendered without `<p>` (tight list items).
    private var isInTightListItem = false

    init(mathSpans: [MathPreprocessor.Span]) {
        self.mathSpans = mathSpans
    }

    // MARK: Helpers

    /// Original source for any text that must not contain math markup.
    private func restored(_ string: String) -> String {
        MathPreprocessor.restore(string, spans: mathSpans)
    }

    private mutating func visitChildren(of markup: any Markup) {
        for child in markup.children {
            visit(child)
        }
    }

    private mutating func wrap(_ tag: String, _ markup: any Markup, attributes: String = "") {
        html += "<\(tag)\(attributes)>"
        visitChildren(of: markup)
        html += "</\(tag)>"
    }

    mutating func defaultVisit(_ markup: any Markup) {
        visitChildren(of: markup)
    }

    // MARK: Blocks

    mutating func visitDocument(_ document: Document) {
        visitChildren(of: document)
    }

    mutating func visitHeading(_ heading: Markdown.Heading) {
        let text = restored(heading.plainText)
        let slug = slugifier.uniqueSlug(for: text)
        headings.append(MdViewerCore.Heading(level: heading.level, text: text, slug: slug))
        let tag = "h\(heading.level)"
        html += "<\(tag) id=\"\(HTMLEscaping.attribute(slug))\">"
        visitChildren(of: heading)
        html += "</\(tag)>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        if isInTightListItem {
            visitChildren(of: paragraph)
        } else {
            wrap("p", paragraph)
            html += "\n"
        }
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        let saved = isInTightListItem
        isInTightListItem = false
        html += "<blockquote>\n"
        visitChildren(of: blockQuote)
        html += "</blockquote>\n"
        isInTightListItem = saved
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        let language = codeBlock.language?
            .split(whereSeparator: { $0.isWhitespace })
            .first
            .map(String.init)
        let code = restored(codeBlock.code)
        switch language?.lowercased() {
        case "math":
            features.containsMath = true
            let tex = code.trimmingCharacters(in: .whitespacesAndNewlines)
            html += "<div class=\"math math-display\">\(HTMLEscaping.text(tex))</div>\n"
        case "mermaid":
            features.containsMermaid = true
            html += "<pre class=\"mermaid\">\(HTMLEscaping.text(code))</pre>\n"
        default:
            let classAttribute = language.map { " class=\"language-\(HTMLEscaping.attribute($0))\"" } ?? ""
            html += "<pre><code\(classAttribute)>\(HTMLEscaping.text(code))</code></pre>\n"
        }
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) {
        self.html += restored(html.rawHTML)
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        html += "<hr />\n"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        let isTask = unorderedList.listItems.contains { $0.checkbox != nil }
        html += isTask ? "<ul class=\"contains-task-list\">\n" : "<ul>\n"
        visitChildren(of: unorderedList)
        html += "</ul>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) {
        let start = orderedList.startIndex == 1 ? "" : " start=\"\(orderedList.startIndex)\""
        let isTask = orderedList.listItems.contains { $0.checkbox != nil }
        let classAttribute = isTask ? " class=\"contains-task-list\"" : ""
        html += "<ol\(start)\(classAttribute)>\n"
        visitChildren(of: orderedList)
        html += "</ol>\n"
    }

    mutating func visitListItem(_ listItem: ListItem) {
        let saved = isInTightListItem
        // swift-markdown does not expose list tightness; treat an item whose
        // only block is a single paragraph as tight.
        isInTightListItem = listItem.childCount == 1 && listItem.child(at: 0) is Paragraph

        if let checkbox = listItem.checkbox {
            let checked = checkbox == .checked ? " checked" : ""
            html += "<li class=\"task-list-item\"><input type=\"checkbox\" disabled\(checked) /> "
        } else {
            html += "<li>"
        }
        visitChildren(of: listItem)
        html += "</li>\n"
        isInTightListItem = saved
    }

    // MARK: Tables

    private var columnAlignments: [Table.ColumnAlignment?] = []
    private var isInTableHead = false

    mutating func visitTable(_ table: Table) {
        columnAlignments = table.columnAlignments
        html += "<table>\n"
        visitChildren(of: table)
        html += "</table>\n"
        columnAlignments = []
    }

    mutating func visitTableHead(_ tableHead: Table.Head) {
        isInTableHead = true
        html += "<thead>\n<tr>\n"
        visitCells(of: tableHead)
        html += "</tr>\n</thead>\n"
        isInTableHead = false
    }

    mutating func visitTableBody(_ tableBody: Table.Body) {
        guard !tableBody.isEmpty else { return }
        html += "<tbody>\n"
        visitChildren(of: tableBody)
        html += "</tbody>\n"
    }

    mutating func visitTableRow(_ tableRow: Table.Row) {
        html += "<tr>\n"
        visitCells(of: tableRow)
        html += "</tr>\n"
    }

    private mutating func visitCells(of row: any Markup) {
        for (index, child) in row.children.enumerated() {
            guard let cell = child as? Table.Cell else { continue }
            // Cells merged into a neighbour's span have a zero span and are not emitted.
            guard cell.colspan > 0, cell.rowspan > 0 else { continue }
            let tag = isInTableHead ? "th" : "td"
            var attributes = ""
            if index < columnAlignments.count, let alignment = columnAlignments[index] {
                attributes += " style=\"text-align: \(Self.cssValue(for: alignment))\""
            }
            if cell.colspan > 1 { attributes += " colspan=\"\(cell.colspan)\"" }
            if cell.rowspan > 1 { attributes += " rowspan=\"\(cell.rowspan)\"" }
            wrap(tag, cell, attributes: attributes)
            html += "\n"
        }
    }

    private static func cssValue(for alignment: Table.ColumnAlignment) -> String {
        switch alignment {
        case .left: "left"
        case .center: "center"
        case .right: "right"
        }
    }

    // MARK: Inlines

    mutating func visitText(_ text: Text) {
        for segment in MathPreprocessor.segments(of: text.string) {
            switch segment {
            case .text(let string):
                html += HTMLEscaping.text(string)
            case .math(let index) where index < mathSpans.count:
                let span = mathSpans[index]
                features.containsMath = true
                let kind = span.isDisplay ? "math-display" : "math-inline"
                html += "<span class=\"math \(kind)\">\(HTMLEscaping.text(span.tex))</span>"
            case .math:
                break
            }
        }
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) {
        wrap("em", emphasis)
    }

    mutating func visitStrong(_ strong: Strong) {
        wrap("strong", strong)
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) {
        wrap("del", strikethrough)
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        html += "<code>\(HTMLEscaping.text(restored(inlineCode.code)))</code>"
    }

    mutating func visitLink(_ link: Link) {
        var attributes = " href=\"\(HTMLEscaping.attribute(restored(link.destination ?? "")))\""
        if let title = link.title, !title.isEmpty {
            attributes += " title=\"\(HTMLEscaping.attribute(restored(title)))\""
        }
        wrap("a", link, attributes: attributes)
    }

    mutating func visitImage(_ image: Image) {
        var attributes = " src=\"\(HTMLEscaping.attribute(restored(image.source ?? "")))\""
        attributes += " alt=\"\(HTMLEscaping.attribute(restored(image.plainText)))\""
        if let title = image.title, !title.isEmpty {
            attributes += " title=\"\(HTMLEscaping.attribute(restored(title)))\""
        }
        html += "<img\(attributes) />"
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) {
        html += restored(inlineHTML.rawHTML)
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        html += "\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) {
        html += "<br />\n"
    }

    mutating func visitSymbolLink(_ symbolLink: SymbolLink) {
        html += "<code>\(HTMLEscaping.text(restored(symbolLink.destination ?? "")))</code>"
    }
}
