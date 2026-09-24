import SwiftUI

/// Composition root: wires adapters into the use case and the UI.
@main
struct MdViewerApp: App {
    private let renderDocument = RenderDocument(renderer: SwiftMarkdownRenderer())
    private let template = HTMLPageTemplate(assets: .bundled())

    var body: some Scene {
        DocumentGroup(viewing: MarkdownFile.self) { configuration in
            DocumentViewerContainer(
                document: MarkdownDocument(
                    source: configuration.document.text,
                    title: configuration.fileURL?.lastPathComponent ?? "Untitled"
                ),
                fileURL: configuration.fileURL,
                renderDocument: renderDocument,
                template: template
            )
        }
    }
}
