import Foundation
import ProviderPlayback

/// 书籍进度的播放事件：只保留恢复与持久化关心的两种。
@MainActor
enum BookProgressPlaybackEvent {
    /// 播放状态变化。
    case stateChanged(PlaybackStatus)
    /// 当前播放文件变化。
    case assetChanged(url: URL?)
}

/// 书籍进度播放监听句柄。
@MainActor
protocol BookProgressPlaybackObserverHandle: AnyObject {
    /// 停止接收后续播放事件。重复调用无副作用。
    func cancel()
}

/// 书籍进度所需的最小播放能力。
///
/// 与 `PlaybackProgressCapability`（进度条）同源但语义不同：进度条只读位置，
/// 书籍进度需要「恢复播放（带起始时间）、跳转、读取状态与位置」。
@MainActor
protocol BookProgressPlaybackCapability: AnyObject {
    /// 当前播放文件；无播放时为 `nil`。
    var currentURL: URL? { get }

    /// 当前播放位置（秒）。
    var currentTime: TimeInterval { get }

    /// 当前播放状态。
    var state: PlaybackStatus { get }

    /// 跳转到指定时间点（秒）。
    func seek(toTime time: TimeInterval)

    /// 播放指定文件；`startTime` 为 `nil` 时从头播放。
    func play(_ url: URL, startTime: TimeInterval?) async

    /// 订阅进度相关播放事件；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (BookProgressPlaybackEvent) -> Void
    ) -> any BookProgressPlaybackObserverHandle
}

/// 将内核 `PlaybackProviding` 收窄为书籍进度的播放能力。
@MainActor
final class BookProgressPlaybackCapabilityAdapter: BookProgressPlaybackCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「无播放」而非延长其生命周期。
    private weak var playback: (any PlaybackProviding)?

    init(playback: (any PlaybackProviding)?) {
        self.playback = playback
    }

    var currentURL: URL? { playback?.currentURL }
    var currentTime: TimeInterval { playback?.currentTime ?? 0 }
    var state: PlaybackStatus { playback?.state ?? .idle }

    func seek(toTime time: TimeInterval) {
        playback?.seek(toTime: time)
    }

    func play(_ url: URL, startTime: TimeInterval?) async {
        await playback?.play(url, startTime: startTime)
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (BookProgressPlaybackEvent) -> Void
    ) -> any BookProgressPlaybackObserverHandle {
        guard let playback else { return BookProgressPlaybackHandleBox(cancelAction: nil) }
        let handle = playback.addObserver { event in
            switch event {
            case .stateChanged(let state): callback(.stateChanged(state))
            case .assetChanged(let url): callback(.assetChanged(url: url))
            default: break
            }
        }
        return BookProgressPlaybackHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `PlaybackProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class BookProgressPlaybackHandleBox: BookProgressPlaybackObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}