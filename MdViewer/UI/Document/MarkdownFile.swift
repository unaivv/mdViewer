import SwiftUI
import UniformTypeIdentifiers
import MdViewerCore

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
        self.text = MarkdownTextDecoding.decode(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // The app is a viewer; documents are never written.
        throw CocoaError(.featureUnsupported)
    }
}
