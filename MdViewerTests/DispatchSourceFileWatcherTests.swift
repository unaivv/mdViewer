import Foundation
import Synchronization
import Testing
@testable import MdViewer

/// Integration tests against the real file system. Serialized to keep timing predictable.
@Suite("DispatchSourceFileWatcher", .serialized)
struct DispatchSourceFileWatcherTests {
    private let directory: URL
    private let fileURL: URL
    private let watcher = DispatchSourceFileWatcher(debounce: .milliseconds(100))

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "MdViewerTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appending(path: "doc.md")
        try Data("# Initial\n".utf8).write(to: fileURL)
    }

    /// Counts callbacks from the watcher.
    private final class ChangeRecorder: Sendable {
        private let counter = Atomic<Int>(0)

        var count: Int { counter.load(ordering: .sequentiallyConsistent) }

        @Sendable func record() {
            counter.add(1, ordering: .sequentiallyConsistent)
        }

        /// Polls until at least `expected` callbacks arrived; returns `false` on timeout.
        func waitForCount(_ expected: Int, timeout: Duration = .seconds(3)) async -> Bool {
            let deadline = ContinuousClock.now + timeout
            while ContinuousClock.now < deadline {
                if count >= expected { return true }
                try? await Task.sleep(for: .milliseconds(20))
            }
            return count >= expected
        }
    }

    private func append(_ text: String) throws {
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(text.utf8))
    }

    @Test func inPlaceWriteFiresCallback() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let recorder = ChangeRecorder()
        let subscription = watcher.watch(fileURL, onChange: recorder.record)
        defer { subscription.cancel() }

        try append("More text\n")

        #expect(await recorder.waitForCount(1))
    }

    @Test func atomicReplaceFiresAndWatchingContinues() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let recorder = ChangeRecorder()
        let subscription = watcher.watch(fileURL, onChange: recorder.record)
        defer { subscription.cancel() }

        // Writes a temporary file and renames it over the original, like many editors do.
        try Data("# Replaced\n".utf8).write(to: fileURL, options: .atomic)
        #expect(await recorder.waitForCount(1))

        // The watcher must now follow the new inode.
        try await Task.sleep(for: .milliseconds(200))
        let countBefore = recorder.count
        try append("After replace\n")
        #expect(await recorder.waitForCount(countBefore + 1))
    }

    @Test func deleteThenRecreateFiresCallback() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let recorder = ChangeRecorder()
        let subscription = watcher.watch(fileURL, onChange: recorder.record)
        defer { subscription.cancel() }

        // vim-style: move the original away, then write a brand-new file at the path.
        let backup = directory.appending(path: "doc.md~")
        try FileManager.default.moveItem(at: fileURL, to: backup)
        try await Task.sleep(for: .milliseconds(150))
        try Data("# New file\n".utf8).write(to: fileURL)

        #expect(await recorder.waitForCount(1))
        #expect(try String(contentsOf: fileURL, encoding: .utf8) == "# New file\n")
    }

    @Test func burstsAreDebounced() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let recorder = ChangeRecorder()
        let subscription = watcher.watch(fileURL, onChange: recorder.record)
        defer { subscription.cancel() }

        for index in 0..<5 {
            try append("line \(index)\n")
        }
        #expect(await recorder.waitForCount(1))
        try await Task.sleep(for: .milliseconds(400))

        #expect(recorder.count == 1)
    }

    @Test func cancelledSubscriptionStaysSilent() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let recorder = ChangeRecorder()
        let subscription = watcher.watch(fileURL, onChange: recorder.record)
        subscription.cancel()
        try await Task.sleep(for: .milliseconds(50))

        try append("Ignored\n")

        try await Task.sleep(for: .milliseconds(400))
        #expect(recorder.count == 0)
    }
}
