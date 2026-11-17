import Foundation
import ProviderPlayback

/// 载入横幅关心的播放事件：只保留状态与当前资源。
@MainActor
enum BookLoadingPlaybackEvent {
    case stateChanged(PlaybackStatus)
    case assetChanged(URL?)
}

/// 播放监听句柄。
@MainActor
protocol BookLoadingPlaybackObserverHandle: AnyObject {
    /// 停止接收后续事件。重复调用无副作用。
    func cancel()
}

/// 载入横幅所需的最小播放能力。
///
/// 内核 `PlaybackProviding` 还包含大量播放控制能力，横幅只消费
/// 「状态 + 当前资源 + 取消/重试」。
@MainActor
protocol BookLoadingPlaybackCapability: AnyObject {
    var state: PlaybackStatus { get }
    var currentURL: URL? { get }

    func cancelPendingLoad()
    func retryLastFailedLoad() async

    @discardableResult
    func addObserver(
        _ callback: @escaping (BookLoadingPlaybackEvent) -> Void
    ) -> any BookLoadingPlaybackObserverHandle
}

/// 将内核 `PlaybackProviding` 收窄为横幅需要的最小能力。
@MainActor
final class BookLoadingPlaybackCapabilityAdapter: BookLoadingPlaybackCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为 `idle` 而非延长其生命周期。
    private weak var playback: (any PlaybackProviding)?

    init(playback: (any PlaybackProviding)?) {
        self.playback = playback
    }

    var state: PlaybackStatus { playback?.state ?? .idle }
    var currentURL: URL? { playback?.currentURL }

    func cancelPendingLoad() {
        playback?.cancelPendingLoad()
    }

    func retryLastFailedLoad() async {
        await playback?.retryLastFailedLoad()
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (BookLoadingPlaybackEvent) -> Void
    ) -> any BookLoadingPlaybackObserverHandle {
        guard let playback else { return BookLoadingHandleBox(cancelAction: nil) }
        let handle = playback.addObserver { event in
            switch event {
            case .stateChanged(let state):
                callback(.stateChanged(state))
            case .assetChanged(let url):
                callback(.assetChanged(url))
            default:
                break
            }
        }
        return BookLoadingHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的观察句柄适配为本插件句柄，避免 Provider 类型泄漏到能力协议之外。
@MainActor
private final class BookLoadingHandleBox: BookLoadingPlaybackObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}
