import Foundation

/// Synchronously delivers events to observers and removes them when their handle is cancelled.
@MainActor
public final class EventObserverStore<Event> {
    private var callbacks: [UUID: (Event) -> Void] = [:]

    public init() {}

    @discardableResult
    public func add(_ callback: @escaping (Event) -> Void) -> EventObserverHandle<Event> {
        let id = UUID()
        callbacks[id] = callback
        return EventObserverHandle(store: self, id: id)
    }

    public func send(_ event: Event) {
        for callback in Array(callbacks.values) {
            callback(event)
        }
    }

    fileprivate func remove(id: UUID) {
        callbacks.removeValue(forKey: id)
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
