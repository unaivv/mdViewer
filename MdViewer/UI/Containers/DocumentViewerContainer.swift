import SwiftUI

/// Container: owns the viewer state (rendered page, outline, live reload, find) and
/// wires use cases to the presentational views.
struct DocumentViewerContainer: View {
    let document: MarkdownDocument
    let fileURL: URL?
    let renderDocument: RenderDocument
    let watchDocument: WatchDocument
    let template: HTMLPageTemplate

    /// The latest version read from disk, overriding `document` after an external change.
    @State private var liveDocument: MarkdownDocument?
    @State private var page: RenderedPage?
    @State private var activeSlug: String?
    @State private var webViewProxy = MarkdownWebViewProxy()

    @State private var isFindBarVisible = false
    @State private var findQuery = ""
    @State private var findStatus = FindStatus.idle
    @State private var findFocusToken = 0

    private var currentDocument: MarkdownDocument { liveDocument ?? document }

    var body: some View {
        DocumentViewerView(
            pageHTML: page?.html,
            baseURL: fileURL?.deletingLastPathComponent(),
            outline: page?.outline ?? [],
            activeSlug: activeSlug,
            webViewProxy: webViewProxy,
            isFindBarVisible: isFindBarVisible,
            findQuery: $findQuery,
            findStatus: findStatus,
            findFocusToken: findFocusToken,
            onSelectHeading: { webViewProxy.scrollToHeading(slug: $0.heading.slug) },
            onActiveHeadingChange: { activeSlug = $0 },
            onFindNext: { find(backwards: false) },
            onFindPrevious: { find(backwards: true) },
            onCloseFind: closeFindBar
        )
        .frame(minWidth: 640, minHeight: 400)
        .task(id: currentDocument) { await render(currentDocument) }
        .task(id: fileURL) { await watchForChanges() }
        .onChange(of: document) { liveDocument = nil }
        .onChange(of: findQuery) { find(backwards: false) }
        .focusedSceneValue(\.findActions, FindActions(
            showFindBar: showFindBar,
            findNext: { isFindBarVisible ? find(backwards: false) : showFindBar() },
            findPrevious: { isFindBarVisible ? find(backwards: true) : showFindBar() }
        ))
    }

    // MARK: Rendering and live reload

    private func render(_ document: MarkdownDocument) async {
        let renderDocument = renderDocument
        let template = template
        page = await Task.detached(priority: .userInitiated) {
            let rendered = renderDocument.execute(document)
            return RenderedPage(
                html: template.page(title: document.title, body: rendered.html),
                outline: TableOfContents.entries(from: rendered.headings)
            )
        }.value
    }

    private func watchForChanges() async {
        guard let fileURL else { return }
        for await updated in watchDocument.updates(of: fileURL, title: fileURL.lastPathComponent) {
            liveDocument = updated
        }
    }

    // MARK: Find

    private func showFindBar() {
        isFindBarVisible = true
        findFocusToken += 1
    }

    private func closeFindBar() {
        isFindBarVisible = false
        findStatus = .idle
    }

    private func find(backwards: Bool) {
        let query = findQuery
        guard !query.isEmpty else {
            findStatus = .idle
            return
        }
        Task {
            let found = await webViewProxy.find(query, backwards: backwards)
            // Ignore results for a query the user has already changed.
            guard query == findQuery else { return }
            findStatus = found ? .found : .notFound
        }
    }
}

/// View-ready output of a render: the full HTML page and its outline.
private struct RenderedPage: Sendable {
    let html: String
    let outline: [OutlineEntry]
}
