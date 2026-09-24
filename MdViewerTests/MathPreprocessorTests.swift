import Testing
@testable import MdViewer

@Suite("MathPreprocessor")
struct MathPreprocessorTests {
    private func placeholder(_ index: Int) -> String {
        "\(MathPreprocessor.placeholderStart)\(index)\(MathPreprocessor.placeholderEnd)"
    }

    @Test func inlineMathIsExtracted() {
        let output = MathPreprocessor.process(#"Energy $E = mc^2$ and $\{x\}$."#)

        #expect(output.markdown == "Energy \(placeholder(0)) and \(placeholder(1)).")
        #expect(output.spans == [
            .init(tex: "E = mc^2", isDisplay: false, raw: "$E = mc^2$"),
            .init(tex: #"\{x\}"#, isDisplay: false, raw: #"$\{x\}$"#),
        ])
    }

    @Test(arguments: [
        "It costs $5 and $10 today.",
        "Price: $ 5 and 6 $",
        "Total $20$30",
        #"Escaped \$x\$ stays text"#,
        "Just one $ sign",
    ])
    func proseDollarsAreNotMath(_ text: String) {
        let output = MathPreprocessor.process(text)

        #expect(output.spans.isEmpty)
        #expect(output.markdown == text)
    }

    @Test func inlineCodeSpansAreSkipped() {
        let text = "Use `$HOME` and ``a $b$ c`` here"

        #expect(MathPreprocessor.process(text).spans.isEmpty)
    }

    @Test func fencedCodeBlocksAreSkipped() {
        let text = "```sh\necho $PATH$\n```\n\n~~~\n$x$\n~~~"

        let output = MathPreprocessor.process(text)

        #expect(output.spans.isEmpty)
        #expect(output.markdown == text)
    }

    @Test func inlineDisplayMath() {
        let output = MathPreprocessor.process(#"See $$\sum_i x_i$$ here"#)

        #expect(output.spans == [.init(tex: #"\sum_i x_i"#, isDisplay: true, raw: #"$$\sum_i x_i$$"#)])
    }

    @Test func multilineDisplayBlock() {
        let source = "Intro\n\n$$\n\\begin{matrix} a & b \\\\ c & d \\end{matrix}\n$$\n\nAfter"

        let output = MathPreprocessor.process(source)

        #expect(output.markdown == "Intro\n\n\(placeholder(0))\n\nAfter")
        #expect(output.spans.first?.isDisplay == true)
        #expect(output.spans.first?.tex == "\\begin{matrix} a & b \\\\ c & d \\end{matrix}")
    }

    @Test func unterminatedDisplayBlockIsLeftAlone() {
        let source = "$$\nnot closed\n\nparagraph"

        let output = MathPreprocessor.process(source)

        #expect(output.spans.isEmpty)
        #expect(output.markdown == source)
    }

    @Test func restoreReturnsOriginalSource() {
        let output = MathPreprocessor.process("a $x$ b")

        #expect(MathPreprocessor.restore(output.markdown, spans: output.spans) == "a $x$ b")
    }
}
