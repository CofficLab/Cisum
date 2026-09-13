import Foundation

/// Provider 实现可复用的事件发送器。监听句柄由订阅者显式取消，生命周期不依赖 SwiftUI。
@MainActor
public final class PlaybackObserverStore<Event> {
    private var callbacks: [UUID: (Event) -> Void] = [:]

    public init() {}

    @discardableResult
    public func add(_ callback: @escaping (Event) -> Void) -> PlaybackObserverStoreHandle<Event> {
        let id = UUID()
        callbacks[id] = callback
        return PlaybackObserverStoreHandle(store: self, id: id)
    }

    public func send(_ event: Event) {
        // 先复制回调，允许回调在处理事件时取消自身，不影响当前分发。
        for callback in Array(callbacks.values) {
            callback(event)
        }
    }

    fileprivate func remove(id: UUID) {
        callbacks.removeValue(forKey: id)
    }
}

@MainActor
public final class PlaybackObserverStoreHandle<Event>: PlaybackProvidingObserverHandle {
    private weak var store: PlaybackObserverStore<Event>?
    private let id: UUID
    private var cancelled = false

    fileprivate init(store: PlaybackObserverStore<Event>, id: UUID) {
        self.store = store
        self.id = id
    }

    public func cancel() {
        guard !cancelled else { return }
        cancelled = true
        store?.remove(id: id)
    }
}
