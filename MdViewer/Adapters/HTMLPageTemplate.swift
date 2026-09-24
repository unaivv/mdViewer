import Foundation

/// Adapter: wraps a rendered HTML fragment into a full HTML page.
///
/// Stylesheets, scripts and fonts are served from the app bundle through the
/// `mdviewer-resource://` scheme (see `WebResourceLocator`), so the page never touches
/// the network and heavy libraries (KaTeX, Mermaid) are only referenced when the
/// document actually uses them.
public struct HTMLPageTemplate: Sendable {
    /// Name of the `WKScriptMessageHandler` that receives the active heading's id
    /// (must match `viewer.js`).
    public static let activeHeadingMessageName = "activeHeading"

    public init() {}

    public func page(title: String, body: String, features: DocumentFeatures) -> String {
        var head: [String] = [
            stylesheet("themes.css"),
            stylesheet("markdown.css"),
            stylesheet("highlight/github.min.css", media: "print, (prefers-color-scheme: light)"),
            stylesheet("highlight/github-dark.min.css", media: "screen and (prefers-color-scheme: dark)"),
        ]
        var scripts: [String] = [script("highlight/highlight.min.js")]

        if features.containsMath {
            head.append(stylesheet("katex/katex.min.css"))
            scripts.append(script("katex/katex.min.js"))
        }
        if features.containsMermaid {
            scripts.append(script("mermaid/mermaid.min.js"))
        }
        scripts.append(script("viewer.js"))

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="color-scheme" content="light dark">
        <title>\(HTMLEscaping.text(title))</title>
        \(head.joined(separator: "\n"))
        </head>
        <body>
        <article class="markdown-body">
        \(body)
        </article>
        \(scripts.joined(separator: "\n"))
        </body>
        </html>
        """
    }

    private func stylesheet(_ path: String, media: String? = nil) -> String {
        let mediaAttribute = media.map { " media=\"\(HTMLEscaping.attribute($0))\"" } ?? ""
        return "<link rel=\"stylesheet\" href=\"\(WebResourceLocator.url(for: path))\"\(mediaAttribute)>"
    }

    private func script(_ path: String) -> String {
        "<script src=\"\(WebResourceLocator.url(for: path))\"></script>"
    }
}
