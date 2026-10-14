import Foundation
import ProviderPlayback

/// 播放进度事件：只保留进度条关心的两种事件。
@MainActor
enum PlaybackProgressEvent {
    /// 播放状态变化。
    case stateChanged(PlaybackStatus)
    /// 当前播放文件变化。
    case assetChanged(url: URL?)
}

/// 播放进度监听句柄。
@MainActor
protocol PlaybackProgressObserverHandle: AnyObject {
    /// 停止接收后续播放事件。重复调用无副作用。
    func cancel()
}

/// 音频进度条所需的最小播放能力。
///
/// 内核 `PlaybackProviding` 还包含 `next` / `previous` / `setPlayMode` 等
/// 本插件不使用的控制能力，以及 `likedAssets` 之外的大量无关快照，故在此收窄。
/// 保留 `likedAssets` 是因为进度条需据此显示「已喜欢」标记并触发切换。
@MainActor
protocol PlaybackProgressCapability: AnyObject {
    /// 当前播放文件；无播放时为 `nil`。
    var currentURL: URL? { get }

    /// 当前播放状态。
    var state: PlaybackStatus { get }

    /// 当前播放进度（秒）。
    var currentTime: TimeInterval { get }

    /// 已喜欢的文件集合。
    var likedAssets: Set<URL> { get }

    /// 跳转到指定时间点（秒）。
    func seek(toTime time: TimeInterval)

    /// 播放指定文件；`startTime` 为 `nil` 时从头播放。
    func play(_ url: URL, startTime: TimeInterval?) async

    /// 切换当前文件的喜欢状态。
    func toggleCurrentLike()

    /// 订阅播放进度相关事件；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (PlaybackProgressEvent) -> Void
    ) -> any PlaybackProgressObserverHandle
}

/// 将内核 `PlaybackProviding` 收窄为进度条的播放能力。
@MainActor
final class PlaybackProgressCapabilityAdapter: PlaybackProgressCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力应退化为「无播放」而非延长其生命周期。
    private weak var playback: (any PlaybackProviding)?

    init(playback: (any PlaybackProviding)?) {
        self.playback = playback
    }

    var currentURL: URL? { playback?.currentURL }
    var state: PlaybackStatus { playback?.state ?? .idle }
    var currentTime: TimeInterval { playback?.currentTime ?? 0 }
    var likedAssets: Set<URL> { playback?.likedAssets ?? [] }

    func seek(toTime time: TimeInterval) {
        playback?.seek(toTime: time)
    }

    func play(_ url: URL, startTime: TimeInterval?) async {
        await playback?.play(url, startTime: startTime)
    }

    func toggleCurrentLike() {
        playback?.toggleCurrentLike()
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (PlaybackProgressEvent) -> Void
    ) -> any PlaybackProgressObserverHandle {
        guard let playback else { return PlaybackProgressObserverHandleBox(cancelAction: nil) }
        let handle = playback.addObserver { event in
            switch event {
            case .stateChanged(let state):
                callback(.stateChanged(state))
            case .assetChanged(let url):
                callback(.assetChanged(url: url))
            default:
                break
            }
        }
        return PlaybackProgressObserverHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `PlaybackProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class PlaybackProgressObserverHandleBox: PlaybackProgressObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}