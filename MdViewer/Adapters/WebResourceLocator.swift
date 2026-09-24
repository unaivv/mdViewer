import Foundation
import UniformTypeIdentifiers

/// Maps `mdviewer-resource://web/<path>` URLs to files inside the bundled `Web` folder.
public struct WebResourceLocator: Sendable {
    public static let scheme = "mdviewer-resource"
    public static let host = "web"

    private let root: URL

    public init(root: URL) {
        self.root = root.standardizedFileURL
    }

    /// The locator for the `Web` resources folder shipped inside the MdViewerCore framework.
    public static func bundled() -> WebResourceLocator {
        bundled(in: Bundle(for: BundleToken.self))
    }

    /// The locator for the `Web` folder inside `bundle`'s resources.
    public static func bundled(in bundle: Bundle) -> WebResourceLocator {
        WebResourceLocator(root: (bundle.resourceURL ?? bundle.bundleURL).appending(path: "Web", directoryHint: .isDirectory))
    }

    /// The URL a page uses to reference a bundled resource at `path` (relative to `Web`).
    public static func url(for path: String) -> String {
        "\(scheme)://\(host)/\(path)"
    }

    /// The file for a resource URL, or `nil` if the URL is foreign or escapes the root.
    public func fileURL(for url: URL) -> URL? {
        guard url.scheme?.lowercased() == Self.scheme,
              url.host()?.lowercased() == Self.host else { return nil }
        let relativePath = url.path(percentEncoded: false)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !relativePath.isEmpty else { return nil }
        let candidate = root.appending(path: relativePath).standardizedFileURL
        guard candidate.path.hasPrefix(root.path + "/") else { return nil }
        return candidate
    }

    /// The MIME type to serve a file with.
    public static func mimeType(for fileURL: URL) -> String {
        // UTType does not know every web font type.
        switch fileURL.pathExtension.lowercased() {
        case "woff2": return "font/woff2"
        case "woff": return "font/woff"
        default: break
        }
        return UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    }
}

/// Anchor class used to locate this framework's bundle.
private final class BundleToken {}
