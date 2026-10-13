import Foundation
import ProviderPlugin
import SwiftUI

/// 根布局贡献事件：插件贡献变化时需要刷新工具栏与状态区。
@MainActor
enum RootContributionEvent {
    /// 插件贡献（工具栏 / 状态区）发生变化。
    case contributionsChanged
}

/// 贡献监听句柄。
@MainActor
protocol RootContributionObserverHandle: AnyObject {
    /// 停止接收后续贡献变更通知。重复调用无副作用。
    func cancel()
}

/// 根布局所需的插件贡献能力。
///
/// 内核 `PluginProviding` 还包含大量插件管理接口（列表、启停、设置入口等），
/// 根布局只消费「读取工具栏/状态区贡献 + 订阅贡献变更」两项，故在此收窄。
@MainActor
protocol RootContributionCapability: AnyObject {
    /// 当前全部工具栏贡献。
    func getToolBarButtons() -> [(id: String, view: AnyView)]

    /// 当前全部状态区贡献。
    func getStatusViews() -> [AnyView]

    /// 订阅贡献变更；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (RootContributionEvent) -> Void
    ) -> any RootContributionObserverHandle
}

/// 将内核 `PluginProviding` 收窄为根布局的贡献能力。
@MainActor
final class RootContributionCapabilityAdapter: RootContributionCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「空贡献列表」而非延长其生命周期。
    private weak var plugins: (any PluginProviding)?

    init(plugins: (any PluginProviding)?) {
        self.plugins = plugins
    }

    func getToolBarButtons() -> [(id: String, view: AnyView)] {
        plugins?.getToolBarButtons() ?? []
    }

    func getStatusViews() -> [AnyView] {
        plugins?.getStatusViews() ?? []
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (RootContributionEvent) -> Void
    ) -> any RootContributionObserverHandle {
        guard let plugins else { return RootContributionHandleBox(cancelAction: nil) }
        let handle = plugins.addObserver { event in
            guard case .contributionsChanged = event else { return }
            callback(.contributionsChanged)
        }
        return RootContributionHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `PluginProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class RootContributionHandleBox: RootContributionObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}