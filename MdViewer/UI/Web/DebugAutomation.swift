#if DEBUG
import Foundation
import WebKit

/// Debug-only hooks for scripted verification, driven by environment variables:
/// - `MDVIEWER_SCROLL_TO=<slug>`: after the first page load, jump to that heading.
/// - `MDVIEWER_EXPORT_PDF=<path>`: after the first page load, export it as PDF to `<path>`.
@MainActor
enum DebugAutomation {
    private static var didExport = false
    private static var didScroll = false

    static func pageDidFinishLoading(_ webView: WKWebView) {
        if !didScroll, let slug = ProcessInfo.processInfo.environment["MDVIEWER_SCROLL_TO"] {
            didScroll = true
            webView.callAsyncJavaScript(
                "var t = document.getElementById(slug); if (t) { t.scrollIntoView(); }",
                arguments: ["slug": slug], in: nil, in: .page, completionHandler: nil
            )
        }
        guard !didExport, let path = ProcessInfo.processInfo.environment["MDVIEWER_EXPORT_PDF"] else { return }
        didExport = true
        Task { @MainActor in
            // Give KaTeX and Mermaid time to render.
            try? await Task.sleep(for: .seconds(2))
            let success = await WebPrinting.exportPDF(webView, to: URL(filePath: path))
            print("MDVIEWER_EXPORT_PDF finished: \(success)")
        }
    }
}
#endif
