import Foundation

/// Adapter: wraps a rendered HTML fragment into a full, self-contained HTML page.
///
/// All CSS and JavaScript are inlined so the page works with any `baseURL`
/// (the document's folder) and never touches the network.
public struct HTMLPageTemplate: Sendable {
    public struct Assets: Sendable, Equatable {
        public let stylesheet: String
        public let highlightScript: String
        public let highlightLightTheme: String
        public let highlightDarkTheme: String

        public init(stylesheet: String, highlightScript: String, highlightLightTheme: String, highlightDarkTheme: String) {
            self.stylesheet = stylesheet
            self.highlightScript = highlightScript
            self.highlightLightTheme = highlightLightTheme
            self.highlightDarkTheme = highlightDarkTheme
        }

        /// Loads the bundled web assets from `Resources/Web`.
        public static func bundled(in bundle: Bundle = .main) -> Assets {
            func load(_ name: String, _ ext: String) -> String {
                guard let url = bundle.url(forResource: name, withExtension: ext),
                      let contents = try? String(contentsOf: url, encoding: .utf8) else {
                    assertionFailure("Missing bundled resource \(name).\(ext)")
                    return ""
                }
                return contents
            }
            return Assets(
                stylesheet: load("markdown", "css"),
                highlightScript: load("highlight.min", "js"),
                highlightLightTheme: load("github.min", "css"),
                highlightDarkTheme: load("github-dark.min", "css")
            )
        }
    }

    private let assets: Assets

    public init(assets: Assets) {
        self.assets = assets
    }

    public func page(title: String, body: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="color-scheme" content="light dark">
        <title>\(HTMLEscaping.text(title))</title>
        <style>\(assets.stylesheet)</style>
        <style media="(prefers-color-scheme: light)">\(assets.highlightLightTheme)</style>
        <style media="(prefers-color-scheme: dark)">\(assets.highlightDarkTheme)</style>
        </head>
        <body>
        <article class="markdown-body">
        \(body)
        </article>
        <script>\(assets.highlightScript)</script>
        <script>\(Self.bootstrapScript)</script>
        </body>
        </html>
        """
    }

    /// Name of the `WKScriptMessageHandler` that receives the active heading's id.
    public static let activeHeadingMessageName = "activeHeading"

    /// Highlights code blocks, makes `#anchor` links scroll within the page and reports
    /// the heading currently at the top of the viewport to the native side.
    private static let bootstrapScript = """
    (function () {
      if (window.hljs) {
        document.querySelectorAll('pre code').forEach(function (block) {
          window.hljs.highlightElement(block);
        });
      }
      document.addEventListener('click', function (event) {
        var link = event.target.closest('a[href^="#"]');
        if (!link) { return; }
        var id = decodeURIComponent(link.getAttribute('href').slice(1));
        var target = document.getElementById(id);
        if (target) {
          event.preventDefault();
          target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
      });

      var handlers = window.webkit && window.webkit.messageHandlers;
      var handler = handlers && handlers.\(activeHeadingMessageName);
      if (!handler) { return; }
      var headings = Array.prototype.slice.call(
        document.querySelectorAll('.markdown-body :is(h1, h2, h3, h4, h5, h6)[id]'));
      var lastReported = null;
      function reportActiveHeading() {
        var active = headings.length ? headings[0].id : '';
        for (var i = 0; i < headings.length; i++) {
          if (headings[i].getBoundingClientRect().top <= 80) { active = headings[i].id; } else { break; }
        }
        if (active !== lastReported) {
          lastReported = active;
          handler.postMessage(active);
        }
      }
      var scheduled = false;
      window.addEventListener('scroll', function () {
        if (scheduled) { return; }
        scheduled = true;
        window.requestAnimationFrame(function () { scheduled = false; reportActiveHeading(); });
      }, { passive: true });
      window.addEventListener('resize', reportActiveHeading);
      reportActiveHeading();
    })();
    """
}
