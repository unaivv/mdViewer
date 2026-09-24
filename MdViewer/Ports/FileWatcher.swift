import Foundation

/// A running file watch. Cancelling it stops all further change notifications.
public protocol FileWatchSubscription: AnyObject, Sendable {
    func cancel()
}

/// Port: notifies when the file at a URL changes on disk, including atomic replacements.
public protocol FileWatcher: Sendable {
    /// Starts watching `url`. `onChange` may be called on any thread.
    func watch(_ url: URL, onChange: @escaping @Sendable () -> Void) -> any FileWatchSubscription
}
