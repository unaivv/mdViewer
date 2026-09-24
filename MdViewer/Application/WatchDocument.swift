import Foundation

/// Use case: emits a fresh `MarkdownDocument` every time the underlying file changes.
public struct WatchDocument: Sendable {
    private let watcher: any FileWatcher
    private let reader: any DocumentReader

    public init(watcher: any FileWatcher, reader: any DocumentReader) {
        self.watcher = watcher
        self.reader = reader
    }

    /// An endless stream of reloaded documents; the watch stops when the stream is cancelled.
    /// Unreadable intermediate states (e.g. mid-save) are skipped.
    public func updates(of url: URL, title: String) -> AsyncStream<MarkdownDocument> {
        let reader = reader
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let subscription = watcher.watch(url) {
                guard let text = try? reader.readText(at: url) else { return }
                continuation.yield(MarkdownDocument(source: text, title: title))
            }
            continuation.onTermination = { _ in subscription.cancel() }
        }
    }
}
