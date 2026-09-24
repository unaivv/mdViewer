import Foundation
import Synchronization
import Testing
@testable import MdViewerCore

@Suite("WatchDocument use case")
struct WatchDocumentTests {
    /// A watcher whose changes are triggered manually.
    private final class ManualFileWatcher: FileWatcher, @unchecked Sendable {
        private let lock = NSLock()
        private var handlers: [@Sendable () -> Void] = []
        private(set) var cancelCount = 0

        final class Subscription: FileWatchSubscription, @unchecked Sendable {
            let onCancel: @Sendable () -> Void
            init(onCancel: @escaping @Sendable () -> Void) { self.onCancel = onCancel }
            func cancel() { onCancel() }
        }

        func watch(_ url: URL, onChange: @escaping @Sendable () -> Void) -> any FileWatchSubscription {
            lock.withLock { handlers.append(onChange) }
            return Subscription { [self] in lock.withLock { cancelCount += 1 } }
        }

        func triggerChange() {
            lock.withLock { handlers }.forEach { $0() }
        }

        var cancellations: Int { lock.withLock { cancelCount } }
    }

    private final class StubReader: DocumentReader, @unchecked Sendable {
        private let text = Mutex<String?>(nil)
        func set(_ value: String?) { text.withLock { $0 = value } }
        func readText(at url: URL) throws -> String {
            guard let value = text.withLock({ $0 }) else { throw CocoaError(.fileReadNoSuchFile) }
            return value
        }
    }

    @Test func emitsReloadedDocumentOnChange() async {
        let watcher = ManualFileWatcher()
        let reader = StubReader()
        let useCase = WatchDocument(watcher: watcher, reader: reader)
        var iterator = useCase.updates(of: URL(filePath: "/tmp/doc.md"), title: "doc.md").makeAsyncIterator()

        reader.set("# Updated")
        watcher.triggerChange()

        let document = await iterator.next()
        #expect(document == MarkdownDocument(source: "# Updated", title: "doc.md"))
    }

    @Test func skipsUnreadableStates() async {
        let watcher = ManualFileWatcher()
        let reader = StubReader()
        let useCase = WatchDocument(watcher: watcher, reader: reader)
        var iterator = useCase.updates(of: URL(filePath: "/tmp/doc.md"), title: "doc.md").makeAsyncIterator()

        reader.set(nil)
        watcher.triggerChange()
        reader.set("second")
        watcher.triggerChange()

        #expect(await iterator.next()?.source == "second")
    }

    @Test func cancellingTheStreamCancelsTheWatch() async {
        let watcher = ManualFileWatcher()
        let useCase = WatchDocument(watcher: watcher, reader: StubReader())

        let task = Task {
            for await _ in useCase.updates(of: URL(filePath: "/tmp/doc.md"), title: "doc.md") {}
        }
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        await task.value

        #expect(watcher.cancellations == 1)
    }
}
