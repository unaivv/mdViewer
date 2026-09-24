import Foundation

/// Adapter: the JavaScript settings object the page runtime (`viewer.js`) reads, derived
/// from the selected reader theme.
public enum PageSettingsScript {
    /// Mermaid's built-in themes for a reader theme, per appearance.
    public static func mermaidThemes(for theme: ReaderTheme) -> (light: String, dark: String) {
        switch theme {
        case .github: ("default", "dark")
        case .sepia, .academic, .highContrast: ("neutral", "dark")
        }
    }

    /// JSON literal of the settings object.
    public static func settingsJSON(for theme: ReaderTheme) -> String {
        let mermaid = mermaidThemes(for: theme)
        // All values are fixed identifiers, so plain interpolation yields valid JSON.
        return #"{"theme":"\#(theme.rawValue)","mermaidTheme":{"light":"\#(mermaid.light)","dark":"\#(mermaid.dark)"}}"#
    }

    /// Runs before the page's own scripts so the first paint already uses the theme.
    public static func documentStartSource(for theme: ReaderTheme) -> String {
        """
        window.mdViewerSettings = \(settingsJSON(for: theme));
        if (document.documentElement) { document.documentElement.dataset.theme = window.mdViewerSettings.theme; }
        """
    }

    /// Applies a theme to an already loaded page without reloading it.
    public static func liveUpdateSource(for theme: ReaderTheme) -> String {
        "window.mdViewer && window.mdViewer.applySettings(\(settingsJSON(for: theme)));"
    }
}
