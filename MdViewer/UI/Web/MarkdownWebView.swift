import AppKit
import SwiftUI
import WebKit

/// Imperative handle to the web view, owned by a container, for actions that are not
/// state (scrolling to a heading, find).
@MainActor
final class MarkdownWebViewProxy {
    fileprivate weak var webView: WKWebView?

    /// Smoothly scrolls the page so the element with `id == slug` is at the top.
    func scrollToHeading(slug: String) {
        webView?.callAsyncJavaScript(
            "window.mdViewer && window.mdViewer.scrollToHeading(slug);",
            arguments: ["slug": slug],
            in: nil,
            in: .page,
            completionHandler: nil
        )
    }

    func printDocument() async {
        guard let webView else { return }
        await WebPrinting.print(webView)
    }

    func exportPDF(suggestedName: String) async {
        guard let webView else { return }
        await WebPrinting.exportPDFWithSavePanel(webView, suggestedName: suggestedName)
    }

    /// Finds and selects the next (or previous) match, wrapping around. Returns whether a match exists.
    func find(_ query: String, backwards: Bool) async -> Bool {
        guard let webView, !query.isEmpty else { return false }
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        configuration.caseSensitive = false
        configuration.wraps = true
        let result = try? await webView.find(query, configuration: configuration)
        return result?.matchFound ?? false
    }
}

/// Displays a full HTML page in a `WKWebView`.
///
/// - External links open in the default browser; `#anchor` links scroll in-page.
/// - Reloading different HTML for the same base URL preserves the scroll position.
/// - The heading at the top of the viewport is reported through `onActiveHeadingChange`.
/// - Theme and zoom changes apply live, without reloading (so the scroll position stays).
struct MarkdownWebView: NSViewRepresentable {
    let html: String
    let baseURL: URL?
    let theme: ReaderTheme
    let zoom: Double
    let proxy: MarkdownWebViewProxy
    let onActiveHeadingChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.shouldPrintBackgrounds = true
        configuration.setURLSchemeHandler(BundleResourceSchemeHandler(), forURLScheme: WebResourceLocator.scheme)
        Self.installSettingsScript(for: theme, in: configuration.userContentController)
        context.coordinator.appliedTheme = theme
        configuration.userContentController.add(
            context.coordinator,
            name: HTMLPageTemplate.activeHeadingMessageName
        )
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true
        webView.pageZoom = zoom
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onActiveHeadingChange = onActiveHeadingChange
        proxy.webView = webView

        if webView.pageZoom != zoom {
            webView.pageZoom = zoom
        }
        if coordinator.appliedTheme != theme {
            coordinator.appliedTheme = theme
            // Future loads (live reload) start with the new theme; the current page switches live.
            Self.installSettingsScript(for: theme, in: webView.configuration.userContentController)
            webView.evaluateJavaScript(PageSettingsScript.liveUpdateSource(for: theme), completionHandler: nil)
        }

        guard coordinator.loadedHTML != html || coordinator.loadedBaseURL != baseURL else { return }
        let isReload = coordinator.loadedHTML != nil && coordinator.loadedBaseURL == baseURL
        coordinator.loadedHTML = html
        coordinator.loadedBaseURL = baseURL

        // With a file base URL WebKit grants read access to that folder,
        // so relative image paths resolve next to the document.
        guard isReload else {
            webView.loadHTMLString(html, baseURL: baseURL)
            return
        }
        // Same document re-rendered (e.g. file changed on disk): keep the reader's place.
        webView.evaluateJavaScript("window.scrollY") { [weak webView] result, _ in
            coordinator.pendingScrollY = result as? Double
            webView?.loadHTMLString(html, baseURL: baseURL)
        }
    }

    private static func installSettingsScript(for theme: ReaderTheme, in controller: WKUserContentController) {
        controller.removeAllUserScripts()
        controller.addUserScript(WKUserScript(
            source: PageSettingsScript.documentStartSource(for: theme),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: HTMLPageTemplate.activeHeadingMessageName
        )
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var loadedHTML: String?
        var loadedBaseURL: URL?
        var pendingScrollY: Double?
        var appliedTheme: ReaderTheme?
        var onActiveHeadingChange: ((String) -> Void)?

        // MARK: WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == HTMLPageTemplate.activeHeadingMessageName,
                  let slug = message.body as? String else { return }
            onActiveHeadingChange?(slug)
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            #if DEBUG
            DebugAutomation.pageDidFinishLoading(webView)
            #endif
            guard let scrollY = pendingScrollY else { return }
            pendingScrollY = nil
            webView.evaluateJavaScript("window.scrollTo(0, \(scrollY))", completionHandler: nil)
        }

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
