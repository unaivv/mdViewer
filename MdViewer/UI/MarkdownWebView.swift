import AppKit
import SwiftUI
import WebKit

/// Displays a full HTML page in a `WKWebView`.
///
/// External links open in the default browser; `#anchor` links scroll in-page.
struct MarkdownWebView: NSViewRepresentable {
    let html: String
    let baseURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedHTML != html || context.coordinator.loadedBaseURL != baseURL else { return }
        context.coordinator.loadedHTML = html
        context.coordinator.loadedBaseURL = baseURL
        // With a file base URL WebKit grants read access to that folder,
        // so relative image paths resolve next to the document.
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedHTML: String?
        var loadedBaseURL: URL?

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                return .allow
            }
            // Same-page fragment navigation is handled by the page itself.
            if url.fragment != nil, let current = webView.url, Self.isSameDocument(url, current) {
                return .allow
            }
            switch url.scheme?.lowercased() {
            case "http", "https", "mailto", "file":
                NSWorkspace.shared.open(url)
                return .cancel
            default:
                return .cancel
            }
        }

        private static func isSameDocument(_ lhs: URL, _ rhs: URL) -> Bool {
            var left = URLComponents(url: lhs, resolvingAgainstBaseURL: true)
            var right = URLComponents(url: rhs, resolvingAgainstBaseURL: true)
            left?.fragment = nil
            right?.fragment = nil
            return left?.url == right?.url
        }
    }
}
