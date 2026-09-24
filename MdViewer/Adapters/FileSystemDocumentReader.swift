import Foundation

/// Adapter: reads Markdown text straight from the file system.
public struct FileSystemDocumentReader: DocumentReader {
    public init() {}

    public func readText(at url: URL) throws -> String {
        MarkdownTextDecoding.decode(try Data(contentsOf: url))
    }
}
