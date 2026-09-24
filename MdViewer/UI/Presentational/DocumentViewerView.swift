import SwiftUI

/// Presentational view: shows a rendered page, or a progress indicator while rendering.
struct DocumentViewerView: View {
    let pageHTML: String?
    let baseURL: URL?

    var body: some View {
        if let pageHTML {
            MarkdownWebView(html: pageHTML, baseURL: baseURL)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    DocumentViewerView(pageHTML: "<h1>Preview</h1><p>Hello</p>", baseURL: nil)
        .frame(width: 600, height: 400)
}
