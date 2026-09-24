import SwiftUI

/// Container: renders the document through the use case and feeds the presentational view.
struct DocumentViewerContainer: View {
    let document: MarkdownDocument
    let fileURL: URL?
    let renderDocument: RenderDocument
    let template: HTMLPageTemplate

    @State private var pageHTML: String?

    var body: some View {
        DocumentViewerView(pageHTML: pageHTML, baseURL: fileURL?.deletingLastPathComponent())
            .frame(minWidth: 480, minHeight: 360)
            .task(id: document) {
                let renderDocument = renderDocument
                let template = template
                let document = document
                pageHTML = await Task.detached(priority: .userInitiated) {
                    let rendered = renderDocument.execute(document)
                    return template.page(title: document.title, body: rendered.html)
                }.value
            }
    }
}
