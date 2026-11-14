import Foundation
import ProviderScene

/// 书籍进度关心的场景信号：切离「有声书」场景时结束进度会话。
@MainActor
enum BookProgressSceneEvent {
    /// 当前场景切换。
    case selectionChanged(scene: AppScene?)
}

/// 场景监听句柄。
@MainActor
protocol BookProgressSceneObserverHandle: AnyObject {
    /// 停止接收后续场景变更通知。重复调用无副作用。
    func cancel()
}

/// 书籍进度所需的最小场景能力。
///
/// 本插件是被动响应方，只读取当前场景以决定「是否属于有声书进度会话」，
/// 不消费 `setCurrentScene` / `restoreCurrentScene` 等写入能力。
@MainActor
protocol BookProgressSceneCapability: AnyObject {
    /// 当前激活场景；尚未恢复时为 `nil`。
    var currentScene: AppScene? { get }

    /// 订阅场景切换；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (BookProgressSceneEvent) -> Void
    ) -> any BookProgressSceneObserverHandle
}

/// 将内核 `SceneProviding` 收窄为书籍进度的场景能力。
@MainActor
final class BookProgressSceneCapabilityAdapter: BookProgressSceneCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「非有声书场景」而非延长其生命周期。
    private weak var scene: (any SceneProviding)?

    init(scene: (any SceneProviding)?) {
        self.scene = scene
    }

    var currentScene: AppScene? { scene?.currentScene }

    @discardableResult
    func addObserver(
        _ callback: @escaping (BookProgressSceneEvent) -> Void
    ) -> any BookProgressSceneObserverHandle {
        guard let scene else { return BookProgressSceneHandleBox(cancelAction: nil) }
        let handle = scene.addObserver { event in
            guard case let .selectionChanged(newScene) = event else { return }
            callback(.selectionChanged(scene: newScene))
        }
        return BookProgressSceneHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `SceneProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class BookProgressSceneHandleBox: BookProgressSceneObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}