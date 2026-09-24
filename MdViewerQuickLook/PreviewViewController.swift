import AppKit
import MdViewerCore
import Quartz
import WebKit

/// Quick Look preview for Markdown files (Space in Finder).
///
/// View-based (`QLPreviewingController` + `WKWebView`) rather than a data-based
/// `QLPreviewReply`: HTML replies are displayed without running JavaScript, which would
/// lose syntax highlighting, KaTeX math and Mermaid diagrams.
final class PreviewViewController: NSViewController, QLPreviewingController {
    private let renderDocument = RenderDocument(renderer: SwiftMarkdownRenderer())
    private let template = HTMLPageTemplate()
    private let loadObserver = LoadObserver()
    private var webView: WKWebView?

    override func loadView() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(BundleResourceSchemeHandler(), forURLScheme: WebResourceLocator.scheme)
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 700), configuration: configuration)
        webView.navigationDelegate = loadObserver
        self.webView = webView
        view = webView
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let text = try FileSystemDocumentReader().readText(at: url)
        let document = MarkdownDocument(source: text, title: url.lastPathComponent)
        let rendered = renderDocument.execute(document)
        let html = template.page(title: document.title, body: rendered.html, features: rendered.features)

        _ = view  // Make sure the web view exists.
        guard let webView else { return }
        // Relative images resolve against the file's folder, but the sandboxed extension
        // may only be allowed to read the previewed file itself.
        await loadObserver.load(html, baseURL: url.deletingLastPathComponent(), in: webView)
    }
}

/// Resolves once the page has finished loading (or failed), so Quick Look shows a
/// rendered page instead of a blank one. Gives up after a short timeout.
@MainActor
private final class LoadObserver: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Never>?

    func load(_ html: String, baseURL: URL, in webView: WKWebView) async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            webView.loadHTMLString(html, baseURL: baseURL)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(3))
                self?.resume()
            }
        }
    }

    private func resume() {
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        resume()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        resume()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        resume()
    }

    /// Links are not followed inside the preview.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        navigationAction.navigationType == .linkActivated && navigationAction.request.url?.fragment == nil ? .cancel : .allow
    }
}
