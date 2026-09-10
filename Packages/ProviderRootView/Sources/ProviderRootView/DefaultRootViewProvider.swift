import KernelCore
import SwiftUI

/// 默认 `RootViewProviding` 实现：持有各区域注入视图 + 内核引用，
/// 渲染 Cisum 根布局（控制区 + 内容区 + 状态区 + 工具栏）。
///
/// 状态变更通过 `RootViewProvidingEvent` 监听机制广播（对齐其他 providing），
/// 不依赖 `ObservableObject`。
@MainActor
public final class DefaultRootViewProvider: RootViewProviding {
    public private(set) var controlView: AnyView?
    public private(set) var contentView: AnyView?
    public private(set) var statusView: AnyView?
    public private(set) var toolbarContent: AnyView?
    public private(set) var overlays: [RootOverlayItem] = []
    public private(set) var isContentViewVisible = false
    private let eventObservers = KernelEventObserverStore<RootViewProvidingEvent>()

    private let kernel: CisumKernel

    public init(kernel: CisumKernel) {
        self.kernel = kernel
    }

    public func setControlView(_ view: AnyView?) {
        controlView = view
        eventObservers.send(.controlViewChanged)
    }

    public func setContentView(_ view: AnyView?) {
        contentView = view
        eventObservers.send(.contentViewChanged)
    }

    public func setStatusView(_ view: AnyView?) {
        statusView = view
        eventObservers.send(.statusViewChanged)
    }

    public func setToolbarContent(_ view: AnyView?) {
        toolbarContent = view
        eventObservers.send(.toolbarContentChanged)
    }

    public func addOverlays(_ newOverlays: [RootOverlayItem]) {
        for overlay in newOverlays where !overlays.contains(where: { $0.id == overlay.id }) {
            overlays.append(overlay)
        }
        overlays.sort { $0.order < $1.order }
        eventObservers.send(.overlaysChanged)
    }

    public func removeOverlays(ids: Set<String>) {
        let oldCount = overlays.count
        overlays.removeAll { ids.contains($0.id) }
        if overlays.count != oldCount {
            eventObservers.send(.overlaysChanged)
        }
    }

    public func setContentViewVisible(_ visible: Bool) {
        guard isContentViewVisible != visible else { return }
        isContentViewVisible = visible
        eventObservers.send(.contentViewVisibilityChanged)
    }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (RootViewProvidingEvent) -> Void
    ) -> any RootViewProvidingObserverHandle {
        eventObservers.add(callback)
    }

    public func makeRootView() -> AnyView {
        var root = AnyView(RootLayoutView(provider: self, kernel: kernel))
        for overlay in overlays {
            root = overlay.wrap(root)
        }
        return root
    }
}

extension KernelEventObserverHandle: RootViewProvidingObserverHandle {}
