import Foundation
import ProviderScene

/// 有声书控制按钮关心的场景信号。
@MainActor
enum BookControlSceneEvent {
    /// 当前场景切换。
    case selectionChanged(scene: AppScene?)
}

/// 场景监听句柄。
@MainActor
protocol BookControlSceneObserverHandle: AnyObject {
    /// 停止接收后续场景变更通知。重复调用无副作用。
    func cancel()
}

/// 有声书控制按钮所需的最小场景能力。
///
/// 本插件是被动响应方：只读当前场景以决定按钮是否激活，
/// 不消费 `setCurrentScene` / `restoreCurrentScene` 等写入能力。
@MainActor
protocol BookControlSceneCapability: AnyObject {
    /// 当前激活场景；尚未恢复时为 `nil`。
    var currentScene: AppScene? { get }

    /// 订阅场景切换；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (BookControlSceneEvent) -> Void
    ) -> any BookControlSceneObserverHandle
}

/// 将内核 `SceneProviding` 收窄为有声书控制按钮的场景能力。
@MainActor
final class BookControlSceneCapabilityAdapter: BookControlSceneCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「非有声书场景」而非延长其生命周期。
    private weak var scene: (any SceneProviding)?

    init(scene: (any SceneProviding)?) {
        self.scene = scene
    }

    var currentScene: AppScene? { scene?.currentScene }

    @discardableResult
    func addObserver(
        _ callback: @escaping (BookControlSceneEvent) -> Void
    ) -> any BookControlSceneObserverHandle {
        guard let scene else { return BookControlSceneHandleBox(cancelAction: nil) }
        let handle = scene.addObserver { event in
            guard case let .selectionChanged(newScene) = event else { return }
            callback(.selectionChanged(scene: newScene))
        }
        return BookControlSceneHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `SceneProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class BookControlSceneHandleBox: BookControlSceneObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}