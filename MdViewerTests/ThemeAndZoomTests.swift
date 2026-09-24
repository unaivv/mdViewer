import Foundation
import Testing
@testable import MdViewerCore

@Suite("Themes")
struct ThemeTests {
    @Test func everyThemeHasADistinctIdentifierAndName() {
        #expect(Set(ReaderTheme.allCases.map(\.rawValue)).count == ReaderTheme.allCases.count)
        #expect(Set(ReaderTheme.allCases.map(\.displayName)).count == ReaderTheme.allCases.count)
        #expect(ReaderTheme.default == .github)
    }

    @Test(arguments: ReaderTheme.allCases)
    func settingsScriptCarriesThemeAndMermaidMapping(_ theme: ReaderTheme) throws {
        let json = PageSettingsScript.settingsJSON(for: theme)
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        let mermaid = object?["mermaidTheme"] as? [String: String]

        #expect(object?["theme"] as? String == theme.rawValue)
        #expect(mermaid?["light"] == PageSettingsScript.mermaidThemes(for: theme).light)
        #expect(mermaid?["dark"] == "dark")
        #expect(PageSettingsScript.documentStartSource(for: theme).contains(json))
        #expect(PageSettingsScript.liveUpdateSource(for: theme).contains("applySettings(\(json))"))
    }

    @Test func githubUsesMermaidDefaultOthersNeutral() {
        #expect(PageSettingsScript.mermaidThemes(for: .github).light == "default")
        #expect(PageSettingsScript.mermaidThemes(for: .sepia).light == "neutral")
    }

    @Test(arguments: ReaderTheme.allCases)
    func everyThemeIsStyledInThemesCSS(_ theme: ReaderTheme) throws {
        let cssURL = try #require(WebResourceLocator.bundled().fileURL(for: URL(string: "mdviewer-resource://web/themes.css")!))
        let css = try String(contentsOf: cssURL, encoding: .utf8)

        #expect(css.contains(#":root[data-theme="\#(theme.rawValue)"]"#))
    }
}

@Suite("PageZoom")
struct PageZoomTests {
    @Test func stepsAndClamps() {
        #expect(PageZoom.zoomedIn(from: 1.0) == 1.1)
        #expect(PageZoom.zoomedOut(from: 1.0) == 0.9)
        #expect(PageZoom.zoomedIn(from: 3.0) == 3.0)
        #expect(PageZoom.zoomedOut(from: 0.5) == 0.5)
        #expect(PageZoom.clamped(0.1) == 0.5)
        #expect(PageZoom.clamped(1.2300001) == 1.2)
    }

    @Test func noFloatDriftAfterManySteps() {
        var zoom = PageZoom.actualSize
        for _ in 0..<7 { zoom = PageZoom.zoomedIn(from: zoom) }
        for _ in 0..<7 { zoom = PageZoom.zoomedOut(from: zoom) }
        #expect(zoom == PageZoom.actualSize)
    }

    @Test func availability() {
        #expect(!PageZoom.canZoomIn(from: 3.0))
        #expect(!PageZoom.canZoomOut(from: 0.5))
        #expect(PageZoom.canZoomIn(from: 1.0) && PageZoom.canZoomOut(from: 1.0))
    }
}

@Suite("WebResourceLocator")
struct WebResourceLocatorTests {
    private let locator = WebResourceLocator(root: URL(filePath: "/App/Resources/Web", directoryHint: .isDirectory))

    @Test func resolvesPathsInsideRoot() {
        let url = locator.fileURL(for: URL(string: "mdviewer-resource://web/katex/fonts/KaTeX_Main-Regular.woff2")!)

        #expect(url?.path == "/App/Resources/Web/katex/fonts/KaTeX_Main-Regular.woff2")
    }

    @Test(arguments: [
        "mdviewer-resource://web/../../../etc/passwd",
        "mdviewer-resource://web/%2E%2E/secret",
        "mdviewer-resource://other/viewer.js",
        "https://web/viewer.js",
        "mdviewer-resource://web/",
    ])
    func rejectsForeignOrEscapingURLs(_ string: String) {
        #expect(locator.fileURL(for: URL(string: string)!) == nil)
    }

    @Test func mimeTypes() {
        #expect(WebResourceLocator.mimeType(for: URL(filePath: "a.css")) == "text/css")
        #expect(WebResourceLocator.mimeType(for: URL(filePath: "a.woff2")) == "font/woff2")
        #expect(WebResourceLocator.mimeType(for: URL(filePath: "a.js")).contains("javascript"))
    }

    @Test func bundledResourcesExist() throws {
        let bundled = WebResourceLocator.bundled()
        for path in ["viewer.js", "themes.css", "markdown.css", "highlight/highlight.min.js",
                     "katex/katex.min.js", "katex/katex.min.css", "katex/fonts/KaTeX_Main-Regular.woff2",
                     "mermaid/mermaid.min.js"] {
            let url = try #require(bundled.fileURL(for: URL(string: WebResourceLocator.url(for: path))!))
            #expect(FileManager.default.fileExists(atPath: url.path), "\(path)")
        }
    }
}
