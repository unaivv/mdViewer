import Foundation

/// Decodes Markdown file bytes, preferring UTF-8 and falling back to Latin-1.
public enum MarkdownTextDecoding {
    public static func decode(_ data: Data) -> String {
        String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }
}
