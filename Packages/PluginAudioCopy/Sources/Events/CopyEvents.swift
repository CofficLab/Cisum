import Foundation
import SwiftUI

public extension Notification.Name {
    static let copyTaskCountChanged = Notification.Name("copyTaskCountChanged")
    static let copyTaskStarted = Notification.Name("copyTaskStarted")
    static let copyTaskFinished = Notification.Name("copyTaskFinished")
}

public extension View {
    func onCopyTaskCountChanged(perform action: @escaping (Int) -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .copyTaskCountChanged)) { notification in
            guard let count = notification.userInfo?["count"] as? Int else { return }
            action(count)
        }
    }

    func onCopyTaskStarted(perform action: @escaping (Int) -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .copyTaskStarted)) { notification in
            guard let count = notification.userInfo?["count"] as? Int else { return }
            action(count)
        }
    }

    func onCopyTaskFinished(perform action: @escaping (Int) -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .copyTaskFinished)) { notification in
            guard let lastCount = notification.userInfo?["lastCount"] as? Int else { return }
            action(lastCount)
        }
    }
}

public extension NotificationCenter {
    static func postCopyTaskCountChanged(count: Int) {
        postCopyTaskCountChangedOnMain(count: count)
    }

    static func postCopyTaskStarted(count: Int) {
        postCopyTaskStartedOnMain(count: count)
    }

    static func postCopyTaskFinished(count: Int, lastCount: Int) {
        postCopyTaskFinishedOnMain(count: count, lastCount: lastCount)
    }

    private static func postCopyTaskCountChangedOnMain(count: Int) {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: .copyTaskCountChanged, object: nil, userInfo: ["count": count])
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .copyTaskCountChanged, object: nil, userInfo: ["count": count])
            }
        }
    }

    private static func postCopyTaskStartedOnMain(count: Int) {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: .copyTaskStarted, object: nil, userInfo: ["count": count])
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .copyTaskStarted, object: nil, userInfo: ["count": count])
            }
        }
    }

    private static func postCopyTaskFinishedOnMain(count: Int, lastCount: Int) {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: .copyTaskFinished, object: nil, userInfo: ["count": count, "lastCount": lastCount])
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .copyTaskFinished, object: nil, userInfo: ["count": count, "lastCount": lastCount])
            }
        }
    }
}
