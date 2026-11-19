import KernelCore
import ProviderAppState
import ProviderRootView

/// 内容区显隐的协调器（`ContentViewVisibilityProviding` 的实现）。
///
/// 这里是**唯一**同时知道「落盘真源」与「根视图」的地方——跨特性的装配
/// 属于组合根（App target 的 `CisumHostWiring`），插件只通过 `Provider*`
/// 契约调用，不依赖任何其他插件的实现包。
///
/// 规则：
/// 1. `AppStateProviding` 是显隐的唯一真源，且**只有用户显式操作才会写它**；
/// 2. 真源变更单向投影到根视图（启动时同步一次，之后跟随事件）；
/// 3. 切换的目标态以**根视图当前实际可见性**取反，而不是落盘值：
///    桌面端「窗口太矮自动收起副栏」只改内存态，若按落盘值取反，
///    用户在矮窗口下点「更多」会得到「点了没反应」。
@MainActor
final class ContentViewVisibilityCoordinator: ContentViewVisibilityProviding {
    private let appState: any AppStateProviding
    private let root: any RootViewProviding
    private var handle: (any AppStateProvidingObserverHandle)?

    init(appState: any AppStateProviding, root: any RootViewProviding) {
        self.appState = appState
        self.root = root
    }

    /// 启动同步：把落盘态灌入根视图，并订阅后续变更。
    ///
    /// 幂等：重复调用只会重设一次根视图状态并换掉订阅句柄。
    func start() {
        root.setContentViewVisible(appState.isDBViewVisible)
        handle?.cancel()
        handle = appState.addObserver { [weak self] event in
            guard case .dbViewVisibilityChanged(let visible) = event else { return }
            self?.root.setContentViewVisible(visible)
        }
    }

    /// 停止同步（内核销毁时调用）。
    func stop() {
        handle?.cancel()
        handle = nil
    }

    var isContentViewVisible: Bool { root.isContentViewVisible }

    func setContentViewVisible(_ visible: Bool) {
        // 先写真源：`setDBView` 落盘并广播，`start()` 的订阅者会把同样的值
        // 投影回根视图。
        appState.setDBView(visible)
        // 再直接写根视图：落盘态本就等于目标态时 `setDBView` 不会广播
        // （`BasicAppStateService` 只在值变化时发事件），此时只有直接写
        // 才能纠正「内存态与落盘态分叉」——例如桌面端窗口高度自适应把副栏收起后，
        // 用户点「更多」必须能把内容区带回来。
        root.setContentViewVisible(visible)
    }

    func toggleContentView() {
        let before = root.isContentViewVisible
        setContentViewVisible(!before)
    }
}