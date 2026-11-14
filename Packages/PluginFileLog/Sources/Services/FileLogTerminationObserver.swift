import Foundation
#if os(macOS)
    import AppKit
#endif

#if os(macOS)
final class FileLogTerminationObserver: @unchecked Sendable {
    static let shared = FileLogTerminationObserver()

    private let lock = NSLock()
    private var token: NSObjectProtocol?

    func start(
        notificationCenter: NotificationCenter = .default,
        stop: @escaping @Sendable () -> Void = {
            FileLogCoordinator.shared.stop()
        }
    ) {
        lock.lock()
        defer { lock.unlock() }

        guard token == nil else { return }

        token = notificationCenter.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: nil
        ) { _ in
            stop()
        }
    }

    func stopObserving(notificationCenter: NotificationCenter = .default) {
        lock.lock()
        defer { lock.unlock() }

        guard let token else { return }

        notificationCenter.removeObserver(token)
        self.token = nil
    }
}
#endif
