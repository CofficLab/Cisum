import SwiftUI

/// 默认 `ContentViewProviding` 实现：持有注入的 Tab 列表，渲染内容区 Tab 容器
/// （迁移自 FactoryCisum `AppTabView`）。
@MainActor
public final class DefaultContentViewProvider: ContentViewProviding, ObservableObject {
    @Published public private(set) var tabs: [ContentTabItem] = []
    @Published public private(set) var isDemoMode = false
    private let eventObservers = ContentViewObserverStore()

    public init() {}

    public func setTabs(_ tabs: [ContentTabItem]) {
        self.tabs = tabs.sorted { $0.order < $1.order }
        eventObservers.send(.tabsChanged(ids: self.tabs.map(\.id)))
    }

    public func setDemoMode(_ enabled: Bool) {
        isDemoMode = enabled
    }

    public func makeContentView() -> AnyView {
        AnyView(ContentAreaView(provider: self, isDemoMode: isDemoMode))
    }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (ContentViewProvidingEvent) -> Void
    ) -> any ContentViewProvidingObserverHandle {
        eventObservers.add(callback)
    }
}

@MainActor
private final class ContentViewObserverStore {
    private var callbacks: [UUID: (ContentViewProvidingEvent) -> Void] = [:]

    @discardableResult
    func add(_ callback: @escaping (ContentViewProvidingEvent) -> Void) -> ContentViewObserverHandle {
        let id = UUID()
        callbacks[id] = callback
        return ContentViewObserverHandle { [weak self] in
            self?.callbacks.removeValue(forKey: id)
        }
    }

    func send(_ event: ContentViewProvidingEvent) {
        for callback in Array(callbacks.values) {
            callback(event)
        }
    }
}

@MainActor
private final class ContentViewObserverHandle: ContentViewProvidingObserverHandle {
    private let cancellation: () -> Void
    private var cancelled = false

    init(_ cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        cancellation()
    }
}
