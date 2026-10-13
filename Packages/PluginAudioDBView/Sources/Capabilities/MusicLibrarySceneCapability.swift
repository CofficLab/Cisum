import ProviderPlayback
import ProviderScene

/// 音乐库场景事件：只保留外壳显隐关心的语义。
@MainActor
enum MusicLibrarySceneEvent {
    /// 当前场景切换；`nil` 表示尚未恢复。
    case selectionChanged(scene: AppScene?)
}

/// 音乐库场景监听句柄。
@MainActor
protocol MusicLibrarySceneObserverHandle: AnyObject {
    /// 停止接收后续场景变更通知。重复调用无副作用。
    func cancel()
}

/// 音乐库外壳所需的最小场景能力。
///
/// 内核 `SceneProviding` 还包含 `setCurrentScene` / `restoreCurrentScene` 等
/// 写入能力；本插件只消费「读取当前场景 + 订阅变更」以决定是否展示
/// root view 外壳，故在此收窄。
@MainActor
protocol MusicLibrarySceneCapability: AnyObject {
    /// 当前激活场景；`nil` 表示尚未恢复。
    var currentScene: AppScene? { get }

    /// 订阅场景切换；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (MusicLibrarySceneEvent) -> Void
    ) -> any MusicLibrarySceneObserverHandle
}

/// 将内核 `SceneProviding` 收窄为音乐库外壳的场景能力。
@MainActor
final class MusicLibrarySceneCapabilityAdapter: MusicLibrarySceneCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力应退化为「非音乐库场景」而非延长其生命周期。
    private weak var scene: (any SceneProviding)?

    init(scene: (any SceneProviding)?) {
        self.scene = scene
    }

    var currentScene: AppScene? { scene?.currentScene }

    @discardableResult
    func addObserver(
        _ callback: @escaping (MusicLibrarySceneEvent) -> Void
    ) -> any MusicLibrarySceneObserverHandle {
        guard let scene else { return MusicLibrarySceneObserverHandleBox(cancelAction: nil) }
        let handle = scene.addObserver { event in
            guard case let .selectionChanged(newScene) = event else { return }
            callback(.selectionChanged(scene: newScene))
        }
        return MusicLibrarySceneObserverHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `SceneProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class MusicLibrarySceneObserverHandleBox: MusicLibrarySceneObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}