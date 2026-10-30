import Foundation
import ProviderRootView

/// 欢迎页关心的根视图「外观区」信号：只关心工具栏的显隐。
///
/// 引导层只是一个覆盖在根视图之外的 overlay，它无法取消内层
/// `RootLayoutView` 已经声明的 `.toolbar` —— 工具栏是真实存在的控件，
/// 不是被遮挡的图层。因此引导必须通过根视图契约**显式抑制**工具栏，
/// 否则首启选择存储位置时窗口顶部仍会挂着设置按钮、场景切换器等功能入口。
///
/// 这里不消费整个 `RootViewProviding`，只收窄出引导期真正需要的一个动作，
/// 避免引导层耦合布局细节。
@MainActor
enum WelcomeRootChromeEvent {
    /// 工具栏显隐状态发生变化。
    case toolbarVisibilityChanged(isHidden: Bool)
}

/// 根视图观察句柄。
@MainActor
protocol WelcomeRootChromeObserverHandle: AnyObject {
    /// 停止接收后续通知。重复调用无副作用。
    func cancel()
}

/// 引导期控制根视图外观区所需的最小能力。
@MainActor
protocol WelcomeRootChromeCapability: AnyObject {
    /// 隐藏或恢复顶部工具栏。
    ///
    /// 引导层展示期间必须传入 `true`，引导关闭后必须恢复为 `false`。
    /// 实现需保证幂等：重复的同向调用无副作用，且**从未隐藏过时不会去
    /// 覆盖其他来源设置的状态**（例如内容区折叠造成的隐藏）。
    func setToolbarHidden(_ hidden: Bool)

    /// 订阅工具栏显隐变化；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (WelcomeRootChromeEvent) -> Void
    ) -> any WelcomeRootChromeObserverHandle
}

/// 将内核 `RootViewProviding` 收窄为引导期需要的工具栏控制能力。
///
/// **持有用 `weak`**：根视图 Provider 可能已被 unregister，此时能力退化为
/// 「工具栏保持现状」而非延长其生命周期。
@MainActor
final class WelcomeRootChromeCapabilityAdapter: WelcomeRootChromeCapability {
    private weak var root: (any RootViewProviding)?

    /// 当前是否已请求隐藏工具栏。用于幂等与 teardown 时精确恢复。
    private var appliedHiddenState: Bool?

    init(root: (any RootViewProviding)?) {
        self.root = root
    }

    func setToolbarHidden(_ hidden: Bool) {
        guard appliedHiddenState != hidden else { return }
        appliedHiddenState = hidden
        root?.setToolbarViewHidden(hidden)
    }

    /// 引导层消失时调用：仅恢复本适配器自己造成的隐藏，
    /// 不去动其他来源（如内容区折叠）设置的状态。
    func restoreIfNeeded() {
        guard let appliedHiddenState, appliedHiddenState else { return }
        self.appliedHiddenState = false
        root?.setToolbarViewHidden(false)
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (WelcomeRootChromeEvent) -> Void
    ) -> any WelcomeRootChromeObserverHandle {
        guard let root else { return WelcomeRootChromeHandleBox(cancelAction: nil) }
        let handle = root.addRootViewObserver { event in
            if case .regionVisibilityChanged(.toolbar, let isHidden) = event {
                callback(.toolbarVisibilityChanged(isHidden: isHidden))
            }
        }
        return WelcomeRootChromeHandleBox(cancelAction: handle.cancel)
    }
}

/// 句柄盒：适配器无需感知内核句柄的具体类型。
@MainActor
final class WelcomeRootChromeHandleBox: WelcomeRootChromeObserverHandle {
    private let cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() { cancelAction?() }
}
