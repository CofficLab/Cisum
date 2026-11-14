import CisumProviderStorage
import Foundation
import ProviderAudioLibrary
import ProviderScene

/// 进度条关心的外部环境信号。
///
/// 场景切换、文件删除、存储位置重置分别来自三个 Provider，但对进度条而言
/// 语义一致——「外部环境变了，进度状态可能需要清理或重算」，故合并为单一能力。
@MainActor
enum ProgressEnvironmentEvent {
    /// 当前场景切换；`nil` 表示尚未恢复。
    case sceneChanged(scene: AppScene?)
    /// 音频文件被删除。
    case filesDeleted([URL])
    /// 存储位置被重置。
    case storageLocationReset
}

/// 外部环境监听句柄。
@MainActor
protocol ProgressEnvironmentObserverHandle: AnyObject {
    /// 停止接收后续外部环境信号。重复调用无副作用。
    func cancel()
}

/// 进度条所需的最小外部环境能力。
///
/// 只暴露「读当前场景 + 订阅三类信号」，不含任何写入能力——本插件是
/// 被动响应方，不负责改变场景、删除文件或重置存储位置。
@MainActor
protocol ProgressEnvironmentCapability: AnyObject {
    /// 当前激活场景；尚未恢复时为 `nil`。
    var currentScene: AppScene? { get }

    /// 订阅外部环境信号；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (ProgressEnvironmentEvent) -> Void
    ) -> any ProgressEnvironmentObserverHandle
}

/// 将内核 `SceneProviding` / `AudioLibraryProviding` / `StorageProviding`
/// 收窄为进度条的外部环境能力。
@MainActor
final class ProgressEnvironmentCapabilityAdapter: ProgressEnvironmentCapability {
    /// 三个来源都用 `weak`：任一 Provider 被 unregister 时对应信号自然消失，
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
        _ callback: @escaping (ProgressEnvironmentEvent) -> Void
    ) -> any ProgressEnvironmentObserverHandle {
        let handles = CompositeObserverHandle()

        if let scene {
            let handle = scene.addObserver { event in
                guard case let .selectionChanged(newScene) = event else { return }
                callback(.sceneChanged(scene: newScene))
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
@MainActor
private final class CompositeObserverHandle: ProgressEnvironmentObserverHandle {
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