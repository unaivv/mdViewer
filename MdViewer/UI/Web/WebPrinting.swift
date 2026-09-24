import AppKit
import WebKit

/// Printing and paginated PDF export for a `WKWebView`, via `NSPrintOperation`.
@MainActor
enum WebPrinting {
    /// Shows the print panel as a sheet and prints the page.
    static func print(_ webView: WKWebView) async {
        guard let window = webView.window else { return }
        await prepare(webView)
        let operation = makeOperation(for: webView, printInfo: basePrintInfo())
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        _ = await run(operation, in: window)
        await finish(webView)
    }

    /// Writes a paginated PDF (paper size and margins from the shared print info) to `url`.
    @discardableResult
    static func exportPDF(_ webView: WKWebView, to url: URL) async -> Bool {
        guard let window = webView.window else { return false }
        await prepare(webView)
        let printInfo = basePrintInfo()
        printInfo.jobDisposition = .save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url
        let operation = makeOperation(for: webView, printInfo: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        let success = await run(operation, in: window)
        await finish(webView)
        return success
    }

    /// Asks for a destination (defaulting to `<name>.pdf`) and exports.
    static func exportPDFWithSavePanel(_ webView: WKWebView, suggestedName: String) async {
        guard let window = webView.window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedName
        guard await panel.beginSheetModal(for: window) == .OK, let url = panel.url else { return }
        if !(await exportPDF(webView, to: url)) {
            NSSound.beep()
        }
    }

    // MARK: Helpers

    private static func basePrintInfo() -> NSPrintInfo {
        let printInfo = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo()
        let margin: CGFloat = 36  // 0.5 inch
        printInfo.topMargin = margin
        printInfo.bottomMargin = margin
        printInfo.leftMargin = margin
        printInfo.rightMargin = margin
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        return printInfo
    }

    private static func makeOperation(for webView: WKWebView, printInfo: NSPrintInfo) -> NSPrintOperation {
        let operation = webView.printOperation(with: printInfo)
        // WKWebView's print view has a zero frame until given one; without it pages come out blank.
        operation.view?.frame = webView.bounds
        return operation
    }

    /// Diagrams switch to their light theme for paper.
    private static func prepare(_ webView: WKWebView) async {
        _ = try? await webView.callAsyncJavaScript(
            "if (window.mdViewer) { await window.mdViewer.prepareForPrint(); }",
            contentWorld: .page
        )
    }

    private static func finish(_ webView: WKWebView) async {
        _ = try? await webView.callAsyncJavaScript(
            "if (window.mdViewer) { await window.mdViewer.finishPrint(); }",
            contentWorld: .page
        )
    }

    private static func run(_ operation: NSPrintOperation, in window: NSWindow) async -> Bool {
        await withCheckedContinuation { continuation in
            let delegate = PrintOperationDelegate { success in continuation.resume(returning: success) }
            operation.runModal(
                for: window,
                delegate: delegate,
                didRun: #selector(PrintOperationDelegate.printOperationDidRun(_:success:contextInfo:)),
                contextInfo: nil
            )
        }
    }
}

/// Bridges `runModal(for:delegate:didRun:contextInfo:)`'s selector callback to a closure.
/// It retains itself until the callback fires.
@MainActor
private final class PrintOperationDelegate: NSObject {
    private var completion: ((Bool) -> Void)?
    private var retainedSelf: PrintOperationDelegate?

    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        super.init()
        retainedSelf = self
    }

    @objc func printOperationDidRun(
        _ operation: NSPrintOperation,
        success: Bool,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        completion?(success)
        completion = nil
        retainedSelf = nil
    }
}
