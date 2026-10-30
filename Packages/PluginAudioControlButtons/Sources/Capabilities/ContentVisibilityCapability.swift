import Foundation
import ProviderAppState

/// 内容区（音乐仓库）显隐监听句柄。
@MainActor
protocol ContentVisibilityObserverHandle: AnyObject {
    /// 停止接收后续显隐变化。重复调用无副作用。
    func cancel()
}

/// 控制按钮引导所需的最小内容区显隐能力。
///
/// 引导只在「仓库视图还没打开」时出现：仓库视图一旦展开，用户自己就能看到
/// 仓库的空态页面，这时候再浮一层提示只是噪音。
@MainActor
protocol ContentVisibilityCapability: AnyObject {
    /// 内容区当前是否可见。
    var isContentViewVisible: Bool { get }

    /// 订阅内容区显隐变化；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (Bool) -> Void
    ) -> any ContentVisibilityObserverHandle
}

/// 将 `AppStateProviding` 收窄为内容区显隐能力。
///
/// 取 `AppStateProviding` 而不是 `ContentViewVisibilityProviding`：显隐的**唯一
/// 真源**是 `AppStateProviding`（用户显式选择，落盘），根视图只是它的一层投影。
///
/// 事件值直接取事件自带的 `visible`，**不**回头读根视图：显隐广播发生在协调器
/// 把新值写进根视图**之前**，此刻读根视图拿到的还是旧值——气泡会慢一次切换。
@MainActor
final class ContentVisibilityCapabilityAdapter: ContentVisibilityCapability {
    private weak var appState: (any AppStateProviding)?

    init(appState: (any AppStateProviding)?) {
        self.appState = appState
    }

    var isContentViewVisible: Bool { appState?.isDBViewVisible ?? false }

    @discardableResult
    func addObserver(
        _ callback: @escaping (Bool) -> Void
    ) -> any ContentVisibilityObserverHandle {
        guard let appState else {
            return ContentVisibilityObserverHandleBox {}
        }

        let handle = appState.addObserver { event in
            guard case .dbViewVisibilityChanged(let visible) = event else { return }
            callback(visible)
        }
        return ContentVisibilityObserverHandleBox { handle.cancel() }
    }
}

/// 将显隐句柄适配为本插件的句柄类型。
@MainActor
private final class ContentVisibilityObserverHandleBox: ContentVisibilityObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: @escaping () -> Void = {}) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}
