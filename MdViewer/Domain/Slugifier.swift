import Foundation

/// Produces GitHub-style heading slugs and de-duplicates repeated ones.
public struct Slugifier: Sendable {
    private var used: Set<String> = []
    private var counters: [String: Int] = [:]

    public init() {}

    /// Returns a unique slug for the given heading text (`foo`, `foo-1`, `foo-2`, ...).
    public mutating func uniqueSlug(for text: String) -> String {
        let base = Self.slug(for: text)
        var candidate = base
        var counter = counters[base] ?? 0
        while used.contains(candidate) {
            counter += 1
            candidate = "\(base)-\(counter)"
        }
        counters[base] = counter
        used.insert(candidate)
        return candidate
    }

    /// Lowercases, keeps letters/digits/`-`/`_`, turns spaces into `-`, drops the rest.
    public static func slug(for text: String) -> String {
        var result = ""
        for scalar in text.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_" {
                result.unicodeScalars.append(scalar)
            } else if scalar == " " {
                result.append("-")
            }
        }
        return result
    }
}
