import Foundation

/// Port: reads the current Markdown text of a document from storage.
public protocol DocumentReader: Sendable {
    func readText(at url: URL) throws -> String
}
