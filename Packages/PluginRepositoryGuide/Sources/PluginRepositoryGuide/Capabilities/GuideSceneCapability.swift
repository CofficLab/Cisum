import Foundation
import ProviderScene

/// 引导关心的场景信号：切离「音乐库」时收起引导。
@MainActor
enum GuideSceneEvent {
    /// 当前场景切换；`nil` 表示尚未恢复。
    case selectionChanged(scene: AppScene?)
}

/// 场景监听句柄。
@MainActor
protocol GuideSceneObserverHandle: AnyObject {
    /// 停止接收后续场景变更通知。重复调用无副作用。
    func cancel()
}

/// 引导所需的最小场景能力。
///
/// 内核 `SceneProviding` 的写入能力（`setCurrentScene` / `restoreCurrentScene`）
/// 本插件不消费——引导是被动响应方，只在「当前是否为音乐库场景」时影响
/// 自己的可见性。
@MainActor
protocol GuideSceneCapability: AnyObject {
    /// 当前激活场景；`nil` 表示尚未恢复。
    var currentScene: AppScene? { get }

    /// 订阅场景切换；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (GuideSceneEvent) -> Void
    ) -> any GuideSceneObserverHandle
}

/// 将内核 `SceneProviding` 收窄为引导用的场景能力。
@MainActor
final class GuideSceneCapabilityAdapter: GuideSceneCapability {
    private weak var scene: (any SceneProviding)?

    init(scene: (any SceneProviding)?) {
        self.scene = scene
    }

    var currentScene: AppScene? { scene?.currentScene }

    @discardableResult
    func addObserver(
        _ callback: @escaping (GuideSceneEvent) -> Void
    ) -> any GuideSceneObserverHandle {
        guard let scene else { return GuideSceneObserverHandleBox(cancelAction: nil) }
        let handle = scene.addObserver { event in
            guard case let .selectionChanged(newScene) = event else { return }
            callback(.selectionChanged(scene: newScene))
        }
        return GuideSceneObserverHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `SceneProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class GuideSceneObserverHandleBox: GuideSceneObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}
