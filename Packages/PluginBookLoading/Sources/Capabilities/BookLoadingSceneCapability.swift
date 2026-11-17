import Foundation
import ProviderScene

/// 载入横幅关心的场景信号。
@MainActor
enum BookLoadingSceneEvent {
    /// 当前场景切换。
    case selectionChanged(scene: AppScene?)
}

/// 场景监听句柄。
@MainActor
protocol BookLoadingSceneObserverHandle: AnyObject {
    /// 停止接收后续场景变更通知。重复调用无副作用。
    func cancel()
}

/// 载入横幅所需的最小场景能力。
///
/// 本插件是被动响应方，只读取当前场景以决定横幅是否属于当前界面，
/// 不消费 `setCurrentScene` / `restoreCurrentScene` 等写入能力。
@MainActor
protocol BookLoadingSceneCapability: AnyObject {
    /// 当前激活场景；尚未恢复时为 `nil`。
    var currentScene: AppScene? { get }

    /// 订阅场景切换；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (BookLoadingSceneEvent) -> Void
    ) -> any BookLoadingSceneObserverHandle
}

/// 将内核 `SceneProviding` 收窄为横幅的场景能力。
@MainActor
final class BookLoadingSceneCapabilityAdapter: BookLoadingSceneCapability {
    private weak var scene: (any SceneProviding)?

    init(scene: (any SceneProviding)?) {
        self.scene = scene
    }

    var currentScene: AppScene? { scene?.currentScene }

    @discardableResult
    func addObserver(
        _ callback: @escaping (BookLoadingSceneEvent) -> Void
    ) -> any BookLoadingSceneObserverHandle {
        guard let scene else { return BookLoadingSceneHandleBox(cancelAction: nil) }
        let handle = scene.addObserver { event in
            guard case let .selectionChanged(newScene) = event else { return }
            callback(.selectionChanged(scene: newScene))
        }
        return BookLoadingSceneHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的场景观察句柄适配为本插件句柄。
@MainActor
private final class BookLoadingSceneHandleBox: BookLoadingSceneObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}
