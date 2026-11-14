import Foundation
import ProviderScene

/// 封面区关心的场景信号：切离「音乐库」时收起封面。
@MainActor
enum HeroSceneEvent {
    /// 当前场景切换。
    case selectionChanged(scene: AppScene?)
}

/// 场景监听句柄。
@MainActor
protocol HeroSceneObserverHandle: AnyObject {
    /// 停止接收后续场景变更通知。重复调用无副作用。
    func cancel()
}

/// 封面区所需的最小场景能力。
///
/// 内核 `SceneProviding` 的写入能力（`setCurrentScene` /
/// `restoreCurrentScene`）本插件不消费——封面区是被动响应方，
/// 只在「当前是否为音乐库场景」时影响自己的可见性。
@MainActor
protocol HeroSceneCapability: AnyObject {
    /// 当前激活场景；尚未恢复时为 `nil`。
    var currentScene: AppScene? { get }

    /// 场景 Provider 是否已注册。
    ///
    /// 缺失 Provider（启动早期）不应让封面永久隐藏，故消费者据此决定
    /// 「无法判断场景时按音乐库场景处理」。
    var isAvailable: Bool { get }

    /// 订阅场景切换；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (HeroSceneEvent) -> Void
    ) -> any HeroSceneObserverHandle
}

/// 将内核 `SceneProviding` 收窄为封面区的场景能力。
@MainActor
final class HeroSceneCapabilityAdapter: HeroSceneCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「非音乐库场景」而非延长其生命周期。
    private weak var scene: (any SceneProviding)?

    init(scene: (any SceneProviding)?) {
        self.scene = scene
    }

    var currentScene: AppScene? { scene?.currentScene }

    /// 场景 Provider 是否可用。
    ///
    /// 封面区据此决定**缺失 Provider 时是否仍按「音乐库场景」处理**：
    /// 场景 Provider 未注册（启动早期）不应让封面永久隐藏，因此
    /// `isMusicSceneActive` 的初值取 `!isAvailable || currentScene == .music`。
    var isAvailable: Bool { scene != nil }

    @discardableResult
    func addObserver(
        _ callback: @escaping (HeroSceneEvent) -> Void
    ) -> any HeroSceneObserverHandle {
        guard let scene else { return HeroSceneObserverHandleBox(cancelAction: nil) }
        let handle = scene.addObserver { event in
            guard case let .selectionChanged(newScene) = event else { return }
            callback(.selectionChanged(scene: newScene))
        }
        return HeroSceneObserverHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `SceneProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class HeroSceneObserverHandleBox: HeroSceneObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}