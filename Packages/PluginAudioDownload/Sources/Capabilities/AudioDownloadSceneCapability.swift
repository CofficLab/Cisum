import Foundation
import ProviderScene

/// 下载器关心的场景信号：只在「音乐库」场景启动预下载。
@MainActor
enum AudioDownloadSceneEvent {
    /// 当前场景切换。
    case selectionChanged(scene: AppScene?)
}

/// 场景监听句柄。
@MainActor
protocol AudioDownloadSceneObserverHandle: AnyObject {
    /// 停止接收后续场景变更通知。重复调用无副作用。
    func cancel()
}

/// 音频自动下载所需的最小场景能力。
///
/// 下载器是被动响应方：只读当前场景以决定是否激活，
/// 不消费 `setCurrentScene` / `restoreCurrentScene` 等写入能力。
@MainActor
protocol AudioDownloadSceneCapability: AnyObject {
    /// 当前激活场景；尚未恢复时为 `nil`。
    var currentScene: AppScene? { get }

    /// 订阅场景切换；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioDownloadSceneEvent) -> Void
    ) -> any AudioDownloadSceneObserverHandle
}

/// 将内核 `SceneProviding` 收窄为音频自动下载的场景能力。
@MainActor
final class AudioDownloadSceneCapabilityAdapter: AudioDownloadSceneCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「非音乐库场景」而非延长其生命周期。
    private weak var scene: (any SceneProviding)?

    init(scene: (any SceneProviding)?) {
        self.scene = scene
    }

    var currentScene: AppScene? { scene?.currentScene }

    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioDownloadSceneEvent) -> Void
    ) -> any AudioDownloadSceneObserverHandle {
        guard let scene else { return AudioDownloadSceneHandleBox(cancelAction: nil) }
        let handle = scene.addObserver { event in
            guard case let .selectionChanged(newScene) = event else { return }
            callback(.selectionChanged(scene: newScene))
        }
        return AudioDownloadSceneHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `SceneProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class AudioDownloadSceneHandleBox: AudioDownloadSceneObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}