import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// The de-facto Markdown type, imported in Info.plist.
    static let markdown = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
}

/// Inbound adapter: a read-only SwiftUI document backed by a Markdown file on disk.
struct MarkdownFile: FileDocument {
    static let readableContentTypes: [UTType] = [.markdown]
    static let writableContentTypes: [UTType] = []

    let text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // The app is a viewer; documents are never written.
        throw CocoaError(.featureUnsupported)
    }
}
