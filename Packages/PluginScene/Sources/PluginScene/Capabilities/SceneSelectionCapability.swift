import Foundation
import ProviderScene

/// 场景选择事件：设置页对内核 `SceneProvidingEvent` 的语义化封装。
///
/// 设置页不关心内核事件的载荷形态（回调执行时 `currentScene` 已更新），
/// 只把事件当作「状态已变，请重新读取」的信号，故在此抹平为无参事件。
@MainActor
enum SceneSelectionEvent {
    /// 当前场景发生变化（或首次就绪）。
    case changed
}

/// 场景选择监听句柄。
@MainActor
protocol SceneSelectionObserverHandle: AnyObject {
    /// 停止接收后续场景变更通知。重复调用无副作用。
    func cancel()
}

/// 场景设置页所需的最小场景能力。
///
/// 与本插件消费 `SceneProviding` 的其他插件不同，这里**保留写入能力**
/// `setCurrentScene(_:)`——场景设置页本身就是「切换场景」这一用户意图的执行者，
/// 收窄掉写入会让 ViewModel 无从表达该意图。
///
/// 但仍剥除其余非消费成员：
/// - `restoreCurrentScene()`：持久化恢复是 `ScenePlugin` 自身的启动职责，
///   设置页无需触发；
/// - `addObserver(_:)` 的事件载荷：见 `SceneSelectionEvent`。
@MainActor
protocol SceneSelectionCapability: AnyObject {
    /// 能力是否已绑定到内核 Provider。
    ///
    /// 用于区分两种状态：**未就绪**（Provider 未注册，视图应隐藏场景区块）
    /// 与 **已就绪但当前场景为 nil**（正常业务状态）。若只靠 `currentScene == nil`
    /// 判断，前者会让 UI 在启动早期误闪。
    var isAvailable: Bool { get }

    /// 所有可用场景（固定内置，即 `AppScene.allCases`）。
    var scenes: [AppScene] { get }

    /// 当前激活的场景；尚未恢复时为 `nil`。
    var currentScene: AppScene? { get }

    /// 切换当前激活的场景（持久化）。
    func setCurrentScene(_ scene: AppScene)

    /// 订阅场景变更；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (SceneSelectionEvent) -> Void
    ) -> any SceneSelectionObserverHandle
}

/// 将内核 `SceneProviding` 收窄为场景设置页的最小能力。
@MainActor
final class SceneSelectionCapabilityAdapter: SceneSelectionCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力应退化为「无可用场景」而非延长其生命周期。
    private weak var scene: (any SceneProviding)?

    init(scene: (any SceneProviding)?) {
        self.scene = scene
    }

    var scenes: [AppScene] { scene?.scenes ?? [] }

    /// 场景尚未注册时返回 `nil`（区别于「已就绪但当前场景为 nil」）。
    var currentScene: AppScene? { scene?.currentScene }

    /// 场景能力是否已绑定到内核 Provider。
    var isAvailable: Bool { scene != nil }

    func setCurrentScene(_ scene: AppScene) {
        self.scene?.setCurrentScene(scene)
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (SceneSelectionEvent) -> Void
    ) -> any SceneSelectionObserverHandle {
        guard let scene else { return SceneSelectionObserverHandleBox(cancelAction: nil) }
        let handle = scene.addObserver { _ in callback(.changed) }
        return SceneSelectionObserverHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `SceneProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class SceneSelectionObserverHandleBox: SceneSelectionObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}