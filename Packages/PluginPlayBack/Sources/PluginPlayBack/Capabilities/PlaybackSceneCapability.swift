import ProviderScene

/// 播放场景事件：本插件关心的场景语义，屏蔽内核 `SceneProvidingEvent` 的原始形态。
@MainActor
enum PlaybackSceneEvent {
    /// 当前激活场景发生变化；`nil` 表示场景尚未恢复。
    case selectionChanged(scene: AppScene?)
}

/// 播放场景监听句柄。
@MainActor
protocol PlaybackSceneObserverHandle: AnyObject {
    /// 停止接收后续场景变更通知。重复调用无副作用。
    func cancel()
}

/// 播放插件所需的最小场景能力。
///
/// 内核 `SceneProviding` 还包含 `setCurrentScene` / `restoreCurrentScene`
/// 等写入能力，本插件只消费「读取当前场景 + 订阅变更」，因此在此收窄。
/// `PlaybackSceneObserver`（场景恢复）与 `PlaybackSettingsSceneObserver`
/// （设置页高亮）消费的是同一组成员，故共用本能力。
@MainActor
protocol PlaybackSceneCapability: AnyObject {
    /// 当前激活场景；`nil` 表示尚未恢复。
    var currentScene: AppScene? { get }

    /// 订阅场景切换；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (PlaybackSceneEvent) -> Void
    ) -> any PlaybackSceneObserverHandle
}

/// 将内核 `SceneProviding` 收窄为播放插件的场景能力。
@MainActor
final class PlaybackSceneCapabilityAdapter: PlaybackSceneCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力应退化为「无场景」而非延长其生命周期。
    private weak var scene: (any SceneProviding)?

    init(scene: (any SceneProviding)?) {
        self.scene = scene
    }

    var currentScene: AppScene? { scene?.currentScene }

    @discardableResult
    func addObserver(
        _ callback: @escaping (PlaybackSceneEvent) -> Void
    ) -> any PlaybackSceneObserverHandle {
        guard let scene else { return PlaybackSceneObserverHandleBox(cancelAction: nil) }
        let handle = scene.addObserver { event in
            guard case let .selectionChanged(newScene) = event else { return }
            callback(.selectionChanged(scene: newScene))
        }
        return PlaybackSceneObserverHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `SceneProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class PlaybackSceneObserverHandleBox: PlaybackSceneObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}