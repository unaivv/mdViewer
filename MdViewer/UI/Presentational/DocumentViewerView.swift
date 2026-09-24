import SwiftUI

/// Presentational view: outline sidebar + (optional find bar and) rendered page.
struct DocumentViewerView: View {
    let pageHTML: String?
    let baseURL: URL?
    let outline: [OutlineEntry]
    let activeSlug: String?
    let webViewProxy: MarkdownWebViewProxy
    let isFindBarVisible: Bool
    @Binding var findQuery: String
    let findStatus: FindStatus
    let findFocusToken: Int
    let onSelectHeading: (OutlineEntry) -> Void
    let onActiveHeadingChange: (String) -> Void
    let onFindNext: () -> Void
    let onFindPrevious: () -> Void
    let onCloseFind: () -> Void

    var body: some View {
        NavigationSplitView {
            OutlineSidebarView(entries: outline, activeSlug: activeSlug, onSelect: onSelectHeading)
                .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 400)
        } detail: {
            VStack(spacing: 0) {
                if isFindBarVisible {
                    FindBarView(
                        query: $findQuery,
                        status: findStatus,
                        focusToken: findFocusToken,
                        onNext: onFindNext,
                        onPrevious: onFindPrevious,
                        onClose: onCloseFind
                    )
                    Divider()
                }
                if let pageHTML {
                    MarkdownWebView(
                        html: pageHTML,
                        baseURL: baseURL,
                        proxy: webViewProxy,
                        onActiveHeadingChange: onActiveHeadingChange
                    )
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}
