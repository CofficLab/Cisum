import CisumProviderStorage
import Foundation
import ProviderAudioLibrary
import ProviderScene

/// 控制按钮关心的外部环境信号。
///
/// 场景切换、文件删除、存储位置重置这三个信号分别来自三个不同的 Provider，
/// 但对控制按钮而言语义相同——「外部环境变了，可能需要恢复播放」——
/// 故合并为单一能力：Observer 不必知道信号来自哪个 Provider，
/// 新增同类信号时也不必再改 Observer 的构造签名。
enum PlaybackEnvironmentEvent {
    /// 当前场景切换。
    case sceneChanged(AppScene?)
    /// 音频文件被删除。
    case filesDeleted([URL])
    /// 存储位置被重置（需要重新解析音频目录）。
    case storageLocationReset
}

/// 外部环境监听句柄。
@MainActor
protocol PlaybackEnvironmentObserverHandle: AnyObject {
    /// 停止接收后续外部环境信号。重复调用无副作用。
    func cancel()
}

/// 播放控制按钮所需的最小外部环境能力。
///
/// 只暴露「读当前场景 + 订阅三类信号」，不含任何控制或写入能力——
/// 本插件是被动响应方，不负责改变场景或存储位置。
@MainActor
protocol PlaybackEnvironmentCapability: AnyObject {
    /// 当前激活场景；尚未恢复时为 `nil`。
    var currentScene: AppScene? { get }

    /// 订阅外部环境信号；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (PlaybackEnvironmentEvent) -> Void
    ) -> any PlaybackEnvironmentObserverHandle
}

/// 将内核 `SceneProviding` / `AudioLibraryProviding` / `StorageProviding`
/// 收窄为控制按钮的外部环境能力。
@MainActor
final class PlaybackEnvironmentCapabilityAdapter: PlaybackEnvironmentCapability {
    /// 三个来源都用 `weak`：任一 Provider 被 unregister 时，对应信号自然消失，
    /// 而不影响其余信号继续工作。
    private weak var scene: (any SceneProviding)?
    private weak var library: (any AudioLibraryProviding)?
    private weak var storage: (any StorageProviding)?

    init(
        scene: (any SceneProviding)?,
        library: (any AudioLibraryProviding)?,
        storage: (any StorageProviding)?
    ) {
        self.scene = scene
        self.library = library
        self.storage = storage
    }

    var currentScene: AppScene? { scene?.currentScene }

    @discardableResult
    func addObserver(
        _ callback: @escaping (PlaybackEnvironmentEvent) -> Void
    ) -> any PlaybackEnvironmentObserverHandle {
        let handles = CompositeObserverHandle()

        if let scene {
            let handle = scene.addObserver { event in
                guard case let .selectionChanged(newScene) = event else { return }
                callback(.sceneChanged(newScene))
            }
            handles.append { handle.cancel() }
        }

        if let library {
            let handle = library.addObserver { event in
                guard case let .deleted(urls, _) = event else { return }
                callback(.filesDeleted(urls))
            }
            handles.append { handle.cancel() }
        }

        if let storage {
            let handle = storage.addObserver { event in
                guard case .locationChanged = event else { return }
                callback(.storageLocationReset)
            }
            handles.append { handle.cancel() }
        }

        return handles
    }
}

/// 聚合多个 Provider 的句柄为单一能力句柄。
///
/// 三个来源中任意一个缺席（Provider 未注册）时 `cancelActions` 可能为空，
/// 此时 `cancel()` 为安全的空操作。
@MainActor
private final class CompositeObserverHandle: PlaybackEnvironmentObserverHandle {
    private var cancelActions: [() -> Void] = []
    private var isCancelled = false

    init() {}

    func append(_ cancelAction: @escaping () -> Void) {
        guard !isCancelled else {
            cancelAction()
            return
        }
        cancelActions.append(cancelAction)
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        for action in cancelActions { action() }
        cancelActions.removeAll()
    }
}