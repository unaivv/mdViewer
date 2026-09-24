import Foundation
import WebKit

/// Serves bundled web resources (CSS, JS, fonts) for `mdviewer-resource://web/...` URLs.
///
/// Serving files instead of inlining them keeps each page small (Mermaid alone is ~3 MB)
/// and lets KaTeX's stylesheet reference its fonts with ordinary relative URLs.
final class BundleResourceSchemeHandler: NSObject, WKURLSchemeHandler {
    private let locator: WebResourceLocator

    init(locator: WebResourceLocator = .bundled()) {
        self.locator = locator
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              let fileURL = locator.fileURL(for: url),
              let data = try? Data(contentsOf: fileURL) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": WebResourceLocator.mimeType(for: fileURL),
                "Content-Length": String(data.count),
                // The page's origin is the document folder (file://); fonts need CORS.
                "Access-Control-Allow-Origin": "*",
                "Cache-Control": "max-age=3600",
            ]
        )
        urlSchemeTask.didReceive(response ?? URLResponse(url: url, mimeType: nil, expectedContentLength: data.count, textEncodingName: nil))
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        // Responses are delivered synchronously; nothing to cancel.
    }
}
