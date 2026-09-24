import SwiftUI

/// Composition root: wires adapters into the use cases and the UI.
@main
struct MdViewerApp: App {
    private let renderDocument = RenderDocument(renderer: SwiftMarkdownRenderer())
    private let watchDocument = WatchDocument(
        watcher: DispatchSourceFileWatcher(),
        reader: FileSystemDocumentReader()
    )
    private let template = HTMLPageTemplate()

    var body: some Scene {
        DocumentGroup(viewing: MarkdownFile.self) { configuration in
            DocumentViewerContainer(
                document: MarkdownDocument(
                    source: configuration.document.text,
                    title: configuration.fileURL?.lastPathComponent ?? "Untitled"
                ),
                fileURL: configuration.fileURL,
                renderDocument: renderDocument,
                watchDocument: watchDocument,
                template: template
            )
        }
        .commands {
            SidebarCommands()
            FindCommands()
            FileCommands()
            ViewCommands()
        }
    }
}
