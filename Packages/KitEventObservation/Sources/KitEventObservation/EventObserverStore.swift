import Foundation

/// Synchronously delivers events to observers and removes them when their handle is cancelled.
@MainActor
public final class EventObserverStore<Event> {
    /// 保持插入顺序的回调表。
    ///
    /// 不用 Dictionary：其遍历顺序是随机的，而 `send` 需要按**注册顺序**投递，
    /// 否则同样一组观察者每次收到的顺序可能不同，调用方无法依赖执行序列。
    private var callbacks: [(id: UUID, callback: (Event) -> Void)] = []

    public init() {}

    @discardableResult
    public func add(_ callback: @escaping (Event) -> Void) -> EventObserverHandle<Event> {
        let id = UUID()
        callbacks.append((id: id, callback: callback))
        return EventObserverHandle(store: self, id: id)
    }

    public func send(_ event: Event) {
        // 复制快照：允许回调内增删观察者而不影响本次遍历
        for entry in callbacks {
            entry.callback(event)
        }
    }

    fileprivate func remove(id: UUID) {
        callbacks.removeAll { $0.id == id }
    }
}

@MainActor
public final class EventObserverHandle<Event>: AnyObject {
    private weak var store: EventObserverStore<Event>?
    private let id: UUID
    private var isCancelled = false

    fileprivate init(store: EventObserverStore<Event>, id: UUID) {
        self.store = store
        self.id = id
    }

    public func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        store?.remove(id: id)
    }
}
