import Darwin
import Foundation

/// Adapter: watches a file with a `DispatchSource` file-system object source.
///
/// Editors such as vim or VS Code often save atomically: they write a new file and
/// rename it over the original, so the watched descriptor ends up pointing at a
/// deleted/renamed inode. On `.delete`/`.rename`/`.revoke` the watcher closes the old
/// descriptor and re-opens the path (retrying briefly while the new file appears).
/// Bursts of events are debounced into a single callback.
public struct DispatchSourceFileWatcher: FileWatcher {
    private let debounce: Duration
    private let reopenAttempts: Int
    private let reopenInterval: Duration

    public init(
        debounce: Duration = .milliseconds(100),
        reopenAttempts: Int = 20,
        reopenInterval: Duration = .milliseconds(50)
    ) {
        self.debounce = debounce
        self.reopenAttempts = reopenAttempts
        self.reopenInterval = reopenInterval
    }

    public func watch(_ url: URL, onChange: @escaping @Sendable () -> Void) -> any FileWatchSubscription {
        let subscription = Subscription(
            url: url,
            debounce: debounce,
            reopenAttempts: reopenAttempts,
            reopenInterval: reopenInterval,
            onChange: onChange
        )
        subscription.start()
        return subscription
    }
}

// MARK: - Subscription

extension DispatchSourceFileWatcher {
    /// All mutable state is confined to `queue`, hence `@unchecked Sendable`.
    final class Subscription: FileWatchSubscription, @unchecked Sendable {
        private let url: URL
        private let debounce: DispatchTimeInterval
        private let reopenAttempts: Int
        private let reopenInterval: DispatchTimeInterval
        private let onChange: @Sendable () -> Void
        private let queue = DispatchQueue(label: "com.unaividal.MdViewer.FileWatcher")

        private var source: (any DispatchSourceFileSystemObject)?
        private var pendingNotification: DispatchWorkItem?
        private var isCancelled = false

        init(
            url: URL,
            debounce: Duration,
            reopenAttempts: Int,
            reopenInterval: Duration,
            onChange: @escaping @Sendable () -> Void
        ) {
            self.url = url
            self.debounce = Self.dispatchInterval(debounce)
            self.reopenAttempts = reopenAttempts
            self.reopenInterval = Self.dispatchInterval(reopenInterval)
            self.onChange = onChange
        }

        deinit {
            source?.cancel()
            pendingNotification?.cancel()
        }

        /// Opens the descriptor synchronously so writes made right after `watch` are observed.
        func start() {
            queue.sync { openSource(attemptsLeft: 0, notifyWhenOpened: false) }
        }

        func cancel() {
            queue.async { [self] in
                isCancelled = true
                pendingNotification?.cancel()
                pendingNotification = nil
                source?.cancel()
                source = nil
            }
        }

        // MARK: Queue-confined

        /// - Parameter notifyWhenOpened: after a replacement the new file may only appear after
        ///   a retry; notifying on (re)open guarantees its final contents are reported.
        private func openSource(attemptsLeft: Int, notifyWhenOpened: Bool) {
            guard !isCancelled, source == nil else { return }
            let descriptor = open(url.path, O_EVTONLY)
            guard descriptor >= 0 else {
                if attemptsLeft > 0 {
                    queue.asyncAfter(deadline: .now() + reopenInterval) { [weak self] in
                        self?.openSource(attemptsLeft: attemptsLeft - 1, notifyWhenOpened: notifyWhenOpened)
                    }
                }
                return
            }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .extend, .attrib, .link, .delete, .rename, .revoke],
                queue: queue
            )
            source.setEventHandler { [weak self] in self?.handleEvent() }
            source.setCancelHandler { close(descriptor) }
            self.source = source
            source.resume()
            if notifyWhenOpened {
                scheduleNotification()
            }
        }

        private func handleEvent() {
            guard let source, !isCancelled else { return }
            let event = source.data
            if !event.isDisjoint(with: [.delete, .rename, .revoke]) {
                // The inode we watch is gone or moved: watch whatever now lives at the path.
                source.cancel()
                self.source = nil
                openSource(attemptsLeft: reopenAttempts, notifyWhenOpened: true)
            } else {
                scheduleNotification()
            }
        }

        private func scheduleNotification() {
            pendingNotification?.cancel()
            let onChange = onChange
            let item = DispatchWorkItem { [weak self] in
                guard let self, !self.isCancelled else { return }
                self.pendingNotification = nil
                onChange()
            }
            pendingNotification = item
            queue.asyncAfter(deadline: .now() + debounce, execute: item)
        }

        private static func dispatchInterval(_ duration: Duration) -> DispatchTimeInterval {
            let (seconds, attoseconds) = duration.components
            return .nanoseconds(Int(seconds) * 1_000_000_000 + Int(attoseconds / 1_000_000_000))
        }
    }
}
