import Foundation
import Markdown

/// Adapter: renders Markdown to HTML using Apple's `swift-markdown` (cmark-gfm) parser.
///
/// swift-markdown ships an `HTMLFormatter`, but it cannot emit heading `id` attributes,
/// so we walk the AST ourselves with a `MarkupVisitor`.
public struct SwiftMarkdownRenderer: MarkdownRenderer {
    public init() {}

    public func render(_ markdown: String) -> RenderedDocument {
        // Smart punctuation is disabled to match GitHub rendering.
        let document = Document(parsing: markdown, options: [.disableSmartOpts])
        var visitor = HTMLVisitor()
        visitor.visit(document)
        return RenderedDocument(html: visitor.html, headings: visitor.headings)
    }
}

// MARK: - HTML visitor

private struct HTMLVisitor: MarkupVisitor {
    typealias Result = Void

    private(set) var html = ""
    private(set) var headings: [Heading] = []
    private var slugifier = Slugifier()
    /// Whether paragraphs should be rendered without `<p>` (tight list items).
    private var isInTightListItem = false

    // MARK: Helpers

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
        let text = heading.plainText
        let slug = slugifier.uniqueSlug(for: text)
        headings.append(MdViewer.Heading(level: heading.level, text: text, slug: slug))
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
        let classAttribute = language.map { " class=\"language-\(HTMLEscaping.attribute($0))\"" } ?? ""
        html += "<pre><code\(classAttribute)>\(HTMLEscaping.text(codeBlock.code))</code></pre>\n"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) {
        self.html += html.rawHTML
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
        html += HTMLEscaping.text(text.string)
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
        html += "<code>\(HTMLEscaping.text(inlineCode.code))</code>"
    }

    mutating func visitLink(_ link: Link) {
        var attributes = " href=\"\(HTMLEscaping.attribute(link.destination ?? ""))\""
        if let title = link.title, !title.isEmpty {
            attributes += " title=\"\(HTMLEscaping.attribute(title))\""
        }
        wrap("a", link, attributes: attributes)
    }

    mutating func visitImage(_ image: Image) {
        var attributes = " src=\"\(HTMLEscaping.attribute(image.source ?? ""))\""
        attributes += " alt=\"\(HTMLEscaping.attribute(image.plainText))\""
        if let title = image.title, !title.isEmpty {
            attributes += " title=\"\(HTMLEscaping.attribute(title))\""
        }
        html += "<img\(attributes) />"
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) {
        html += inlineHTML.rawHTML
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        html += "\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) {
        html += "<br />\n"
    }

    mutating func visitSymbolLink(_ symbolLink: SymbolLink) {
        html += "<code>\(HTMLEscaping.text(symbolLink.destination ?? ""))</code>"
    }
}
