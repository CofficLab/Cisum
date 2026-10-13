import Foundation
import ProviderPlayback

/// 喜欢按钮事件：只保留喜欢判定相关的三种事件。
@MainActor
enum LikeButtonEvent {
    /// 当前播放文件变化。
    case assetChanged(URL?)
    /// 当前文件的喜欢状态变化。
    case likeStatusChanged(Bool)
    /// 已喜欢文件集合变化。
    case likedAssetsChanged(Set<URL>)
}

/// 喜欢按钮监听句柄。
@MainActor
protocol LikeButtonObserverHandle: AnyObject {
    /// 停止接收后续喜欢相关事件。重复调用无副作用。
    func cancel()
}

/// 喜欢按钮所需的最小播放能力。
///
/// 内核 `PlaybackProviding` 的播放控制、进度、跳转等能力本插件不消费；
/// 按钮只判断「有无当前文件 + 当前文件是否已喜欢」并触发切换。
@MainActor
protocol LikeButtonCapability: AnyObject {
    /// 当前播放文件；无播放时为 `nil`。
    var currentURL: URL? { get }

    /// 是否有当前播放文件。
    var hasAsset: Bool { get }

    /// 已喜欢的文件集合。
    var likedAssets: Set<URL> { get }

    /// 切换当前文件的喜欢状态。
    func toggleCurrentLike()

    /// 订阅喜欢相关事件；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (LikeButtonEvent) -> Void
    ) -> any LikeButtonObserverHandle
}

/// 将内核 `PlaybackProviding` 收窄为喜欢按钮的最小能力。
@MainActor
final class LikeButtonCapabilityAdapter: LikeButtonCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「无播放」而非延长其生命周期。
    private weak var playback: (any PlaybackProviding)?

    init(playback: (any PlaybackProviding)?) {
        self.playback = playback
    }

    var currentURL: URL? { playback?.currentURL }
    var hasAsset: Bool { playback?.hasAsset ?? false }
    var likedAssets: Set<URL> { playback?.likedAssets ?? [] }

    func toggleCurrentLike() {
        playback?.toggleCurrentLike()
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (LikeButtonEvent) -> Void
    ) -> any LikeButtonObserverHandle {
        guard let playback else { return LikeButtonHandleBox(cancelAction: nil) }
        let handle = playback.addObserver { event in
            switch event {
            case .assetChanged(let url):
                callback(.assetChanged(url))
            case .likeStatusChanged(_, let liked):
                callback(.likeStatusChanged(liked))
            case .likedAssetsChanged(let assets):
                callback(.likedAssetsChanged(assets))
            default:
                break
            }
        }
        return LikeButtonHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `PlaybackProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class LikeButtonHandleBox: LikeButtonObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}