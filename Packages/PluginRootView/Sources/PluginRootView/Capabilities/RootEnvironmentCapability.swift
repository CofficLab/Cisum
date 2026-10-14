import Foundation
import ProviderAudioLibrary
import ProviderPlayback
import ProviderScene

/// 根布局关心的播放环境信号：驱动「播放器封面是否呈现」。
///
/// 三个来源（播放 / 场景 / 音乐仓库）对根布局而言语义一致——它们共同决定
/// 控制区高度（封面呈现 250 / 无封面收起 150），故合并为单一能力：
/// 根布局不必知道信号来自哪个 Provider。
@MainActor
enum RootEnvironmentEvent {
    /// 当前播放文件变化（`nil` 表示无播放）。
    case assetChanged(URL?)
    /// 当前场景切换。
    case sceneChanged(AppScene?)
    /// 音乐仓库变空（应收起封面）。
    case repositoryEmpty
    /// 音乐仓库恢复非空（应展示封面）。
    case repositoryNonEmpty
}

/// 播放环境监听句柄。
@MainActor
protocol RootEnvironmentObserverHandle: AnyObject {
    /// 停止接收后续环境信号。重复调用无副作用。
    func cancel()
}

/// 根布局所需的最小播放环境能力。
///
/// 只暴露「初始快照（当前文件 / 当前场景）+ 订阅环境信号」，
/// 不含任何写入或控制能力——根布局是被动响应方。
@MainActor
protocol RootEnvironmentCapability: AnyObject {
    /// 当前播放文件；无播放时为 `nil`。
    var currentURL: URL? { get }

    /// 当前激活场景；尚未恢复时为 `nil`。
    var currentScene: AppScene? { get }

    /// 订阅播放环境信号；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (RootEnvironmentEvent) -> Void
    ) -> any RootEnvironmentObserverHandle
}

/// 将内核 `PlaybackProviding` / `SceneProviding` / `AudioLibraryProviding`
/// 收窄为根布局的播放环境能力。
@MainActor
final class RootEnvironmentCapabilityAdapter: RootEnvironmentCapability {
    /// 三个来源都用 `weak`：任一 Provider 被 unregister 时对应信号自然消失，
    /// 而不影响其余信号继续工作。
    private weak var playback: (any PlaybackProviding)?
    private weak var scene: (any SceneProviding)?
    private weak var library: (any AudioLibraryProviding)?

    init(
        playback: (any PlaybackProviding)?,
        scene: (any SceneProviding)?,
        library: (any AudioLibraryProviding)?
    ) {
        self.playback = playback
        self.scene = scene
        self.library = library
    }

    var currentURL: URL? { playback?.currentURL }
    var currentScene: AppScene? { scene?.currentScene }

    @discardableResult
    func addObserver(
        _ callback: @escaping (RootEnvironmentEvent) -> Void
    ) -> any RootEnvironmentObserverHandle {
        let handles = RootEnvironmentCompositeHandle()

        if let playback {
            let handle = playback.addObserver { event in
                guard case let .assetChanged(url) = event else { return }
                callback(.assetChanged(url))
            }
            handles.append { handle.cancel() }
        }

        if let scene {
            let handle = scene.addObserver { event in
                guard case let .selectionChanged(newScene) = event else { return }
                callback(.sceneChanged(newScene))
            }
            handles.append { handle.cancel() }
        }

        if let library {
            let handle = library.addObserver { event in
                switch event {
                case .repositoryEmpty:
                    callback(.repositoryEmpty)
                case .synced(let totalCount), .updated(let totalCount), .deleted(_, let totalCount):
                    // 计数为 0 时不改变可见性，等待 `repositoryEmpty` 权威信号
                    // （保持原根布局行为：仅正数计数确认「已恢复非空」）。
                    if totalCount > 0 { callback(.repositoryNonEmpty) }
                case .syncing, .repositoryAvailabilityChanged, .sorting, .sortCompleted:
                    break
                }
            }
            handles.append { handle.cancel() }
        }

        return handles
    }
}

/// 聚合三个来源的句柄为单一能力句柄。
@MainActor
private final class RootEnvironmentCompositeHandle: RootEnvironmentObserverHandle {
    private var cancelActions: [() -> Void] = []
    private var isCancelled = false

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