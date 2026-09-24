import Foundation

/// Protects TeX math from the Markdown parser.
///
/// cmark knows nothing about math: it would treat `\\`, `\{`, `*` or `_` inside `$...$`
/// as Markdown. Before parsing, each math span is replaced by an opaque placeholder
/// (private-use characters around an index) that cmark passes through as plain text.
/// The HTML visitor turns placeholders in text into math markup, and restores the
/// original source verbatim anywhere else (code spans, code blocks, URLs, raw HTML), so
/// a false positive inside code is harmless.
///
/// Delimiter rules follow Pandoc's `tex_math_dollars`, which keeps prose like
/// "costs $5 and $10" intact:
/// - `$...$` inline: the opening `$` is not followed by whitespace, the closing `$` is
///   not preceded by whitespace and not followed by a digit; single line only.
/// - `$$...$$` display: inline on one line, or as a block starting with a `$$` line.
/// - `\$` is a literal dollar; fenced code blocks and inline code spans are skipped.
struct MathPreprocessor {
    struct Span: Equatable, Sendable {
        /// The TeX source without delimiters.
        let tex: String
        let isDisplay: Bool
        /// The exact original text, delimiters included.
        let raw: String
    }

    struct Output: Equatable, Sendable {
        let markdown: String
        let spans: [Span]
    }

    static let placeholderStart: Character = "\u{E000}"
    static let placeholderEnd: Character = "\u{E001}"

    static func process(_ source: String) -> Output {
        var state = State()
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
        var output: [String] = []
        output.reserveCapacity(lines.count)

        var fence: (character: Character, length: Int)?
        var displayBlock: DisplayBlock?

        for lineSubstring in lines {
            let line = String(lineSubstring)

            if let openFence = fence {
                output.append(line)
                if Self.isClosingFence(line, character: openFence.character, length: openFence.length) {
                    fence = nil
                }
                continue
            }

            if var block = displayBlock {
                if line.allSatisfy(\.isWhitespace) {
                    // A blank line ends the paragraph: this was not display math.
                    output.append(contentsOf: Self.unwind(block, state: &state))
                    output.append(line)
                    displayBlock = nil
                } else if let closing = line.range(of: "$$") {
                    block.rawLines.append(String(line[..<closing.upperBound]))
                    let raw = block.rawLines.joined(separator: "\n")
                    let tex = raw.dropFirst(2).dropLast(2).trimmingCharacters(in: .whitespacesAndNewlines)
                    let placeholder = state.add(Span(tex: tex, isDisplay: true, raw: raw))
                    let rest = String(line[closing.upperBound...])
                    output.append(block.indent + placeholder + Self.processInline(rest, state: &state))
                    displayBlock = nil
                } else {
                    block.rawLines.append(line)
                    displayBlock = block
                }
                continue
            }

            if let openFence = Self.openingFence(line) {
                fence = openFence
                output.append(line)
                continue
            }

            let indent = String(line.prefix { $0 == " " || $0 == "\t" })
            let trimmed = line.dropFirst(indent.count)
            if trimmed.hasPrefix("$$"), !trimmed.dropFirst(2).contains("$$") {
                // A display block opening on its own line: `$$` or `$$ \int ...`.
                displayBlock = DisplayBlock(indent: indent, rawLines: [String(trimmed)])
                continue
            }

            output.append(Self.processInline(line, state: &state))
        }

        if let block = displayBlock {
            output.append(contentsOf: Self.unwind(block, state: &state))
        }

        return Output(markdown: output.joined(separator: "\n"), spans: state.spans)
    }

    /// A `$$` block being collected; `rawLines[0]` is the opening line without indentation.
    private struct DisplayBlock {
        let indent: String
        var rawLines: [String]
    }

    /// Emits the lines of an unterminated display block as ordinary text.
    private static func unwind(_ block: DisplayBlock, state: inout State) -> [String] {
        var lines = block.rawLines
        lines[0] = block.indent + lines[0]
        return lines.map { processInline($0, state: &state) }
    }

    // MARK: - Inline scanning

    private struct State {
        var spans: [Span] = []

        mutating func add(_ span: Span) -> String {
            spans.append(span)
            return "\(MathPreprocessor.placeholderStart)\(spans.count - 1)\(MathPreprocessor.placeholderEnd)"
        }
    }

    private static func processInline(_ line: String, state: inout State) -> String {
        guard line.contains("$") else { return line }
        let characters = Array(line)
        var result = ""
        var index = 0

        while index < characters.count {
            let character = characters[index]

            switch character {
            case "\\":
                // Escaped character (e.g. `\$`): copy both verbatim.
                result.append(character)
                if index + 1 < characters.count { result.append(characters[index + 1]) }
                index += 2

            case "`":
                // Copy a whole code span verbatim; unmatched backticks are literal.
                let runLength = Self.runLength(of: "`", in: characters, from: index)
                if let close = Self.findBacktickRun(length: runLength, in: characters, from: index + runLength) {
                    result.append(contentsOf: characters[index..<(close + runLength)])
                    index = close + runLength
                } else {
                    result.append(contentsOf: characters[index..<(index + runLength)])
                    index += runLength
                }

            case "$":
                if let span = Self.matchDisplay(in: characters, at: index) ?? Self.matchInline(in: characters, at: index) {
                    result += state.add(span.span)
                    index = span.end
                } else {
                    // Copy a run of dollars as-is so `$$` is never re-read as `$`.
                    let runLength = Self.runLength(of: "$", in: characters, from: index)
                    result.append(contentsOf: characters[index..<(index + runLength)])
                    index += runLength
                }

            default:
                result.append(character)
                index += 1
            }
        }
        return result
    }

    private static func matchDisplay(in characters: [Character], at start: Int) -> (span: Span, end: Int)? {
        guard start + 1 < characters.count, characters[start + 1] == "$" else { return nil }
        var index = start + 2
        while index + 1 < characters.count {
            if characters[index] == "\\" { index += 2; continue }
            if characters[index] == "`" { return nil }
            if characters[index] == "$", characters[index + 1] == "$" {
                let tex = String(characters[(start + 2)..<index]).trimmingCharacters(in: .whitespaces)
                guard !tex.isEmpty else { return nil }
                let raw = String(characters[start..<(index + 2)])
                return (Span(tex: tex, isDisplay: true, raw: raw), index + 2)
            }
            index += 1
        }
        return nil
    }

    private static func matchInline(in characters: [Character], at start: Int) -> (span: Span, end: Int)? {
        let next = start + 1
        guard next < characters.count,
              !characters[next].isWhitespace,
              characters[next] != "$" else { return nil }
        var index = next
        while index < characters.count {
            let character = characters[index]
            if character == "\\" { index += 2; continue }
            if character == "`" { return nil }
            if character == "$" {
                let previous = characters[index - 1]
                let following = index + 1 < characters.count ? characters[index + 1] : nil
                if !previous.isWhitespace, !(following?.isNumber ?? false), following != "$" {
                    let tex = String(characters[next..<index])
                    let raw = String(characters[start...index])
                    return (Span(tex: tex, isDisplay: false, raw: raw), index + 1)
                }
                // Not a valid closer (e.g. "$5 and $10"): no math starting here.
                return nil
            }
            index += 1
        }
        return nil
    }

    private static func runLength(of character: Character, in characters: [Character], from start: Int) -> Int {
        var length = 0
        while start + length < characters.count, characters[start + length] == character { length += 1 }
        return length
    }

    private static func findBacktickRun(length: Int, in characters: [Character], from start: Int) -> Int? {
        var index = start
        while index < characters.count {
            if characters[index] == "`" {
                let run = runLength(of: "`", in: characters, from: index)
                if run == length { return index }
                index += run
            } else {
                index += 1
            }
        }
        return nil
    }

    // MARK: - Fences

    private static func openingFence(_ line: String) -> (character: Character, length: Int)? {
        let leadingSpaces = line.prefix { $0 == " " }.count
        guard leadingSpaces <= 3 else { return nil }
        let rest = line.dropFirst(leadingSpaces)
        guard let first = rest.first, first == "`" || first == "~" else { return nil }
        let length = rest.prefix { $0 == first }.count
        guard length >= 3 else { return nil }
        // A backtick fence's info string cannot contain backticks.
        if first == "`", rest.dropFirst(length).contains("`") { return nil }
        return (first, length)
    }

    private static func isClosingFence(_ line: String, character: Character, length: Int) -> Bool {
        let leadingSpaces = line.prefix { $0 == " " }.count
        guard leadingSpaces <= 3 else { return false }
        let rest = line.dropFirst(leadingSpaces)
        let run = rest.prefix { $0 == character }.count
        return run >= length && rest.dropFirst(run).allSatisfy(\.isWhitespace)
    }

    // MARK: - Placeholder resolution

    /// Splits text into literal runs and math span indices.
    enum Segment: Equatable {
        case text(String)
        case math(Int)
    }

    static func segments(of text: String) -> [Segment] {
        guard text.contains(placeholderStart) else { return [.text(text)] }
        var segments: [Segment] = []
        var current = ""
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == placeholderStart,
               let end = text[index...].firstIndex(of: placeholderEnd),
               let number = Int(text[text.index(after: index)..<end]) {
                if !current.isEmpty { segments.append(.text(current)); current = "" }
                segments.append(.math(number))
                index = text.index(after: end)
            } else {
                current.append(character)
                index = text.index(after: index)
            }
        }
        if !current.isEmpty { segments.append(.text(current)) }
        return segments
    }

    /// Replaces placeholders with the original source (for code, URLs, raw HTML, plain text).
    static func restore(_ text: String, spans: [Span]) -> String {
        guard text.contains(placeholderStart) else { return text }
        return segments(of: text).map { segment in
            switch segment {
            case .text(let string): string
            case .math(let index): index < spans.count ? spans[index].raw : ""
            }
        }.joined()
    }
}
