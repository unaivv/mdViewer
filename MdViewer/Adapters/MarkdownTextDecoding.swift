import Foundation

/// Decodes Markdown file bytes, preferring UTF-8 and falling back to Latin-1.
enum MarkdownTextDecoding {
    static func decode(_ data: Data) -> String {
        String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }
}
