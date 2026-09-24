import Foundation

/// HTML escaping helpers shared by the HTML adapters.
enum HTMLEscaping {
    /// Escapes text content for safe inclusion inside HTML elements.
    static func text(_ string: String) -> String {
        var result = ""
        result.reserveCapacity(string.utf8.count)
        for character in string {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            default: result.append(character)
            }
        }
        return result
    }

    /// Escapes a value for safe inclusion inside a double-quoted HTML attribute.
    static func attribute(_ string: String) -> String {
        text(string).replacingOccurrences(of: "'", with: "&#39;")
    }
}
