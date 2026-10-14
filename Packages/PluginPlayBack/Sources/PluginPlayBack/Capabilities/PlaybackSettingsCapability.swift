import Foundation
import ProviderPlayback

/// 播放设置页事件：只保留设置页关心的播放语义。
@MainActor
enum PlaybackSettingsEvent {
    case assetChanged(url: URL?)
    case stateChanged(PlaybackStatus)
    case timeChanged(TimeInterval)
    case durationChanged(TimeInterval)
}

/// 播放设置页监听句柄。
@MainActor
protocol PlaybackSettingsObserverHandle: AnyObject {
    /// 停止接收后续播放事件。重复调用无副作用。
    func cancel()
}

/// 设置页所需的最小播放能力。
///
/// 内核 `PlaybackProviding` 包含 `play` / `pause` / `seek` / `next` 等
/// 大量控制能力与 `likedAssets` / `playMode` 等无关状态，设置页只消费
/// 「只读播放快照 + 播放详情变更事件」，因此在此收窄。
@MainActor
protocol PlaybackSettingsCapability: AnyObject {
    var currentURL: URL? { get }
    var isPlaying: Bool { get }
    var state: PlaybackStatus { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }

    /// 订阅播放详情变更；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (PlaybackSettingsEvent) -> Void
    ) -> any PlaybackSettingsObserverHandle
}

/// 将内核 `PlaybackProviding` 收窄为设置页的播放能力。
@MainActor
final class PlaybackSettingsCapabilityAdapter: PlaybackSettingsCapability {
    /// 持有内核 Provider 用 `weak`：设置页不应因 ViewModel 存活而延长
    /// 播放 Provider 的生命周期；`@Published` 状态本身已是快照。
    private weak var playback: (any PlaybackProviding)?

    init(playback: (any PlaybackProviding)?) {
        self.playback = playback
    }

    var currentURL: URL? { playback?.currentURL }
    var isPlaying: Bool { playback?.isPlaying ?? false }
    var state: PlaybackStatus { playback?.state ?? .idle }
    var currentTime: TimeInterval { playback?.currentTime ?? 0 }
    var duration: TimeInterval { playback?.duration ?? 0 }

    @discardableResult
    func addObserver(
        _ callback: @escaping (PlaybackSettingsEvent) -> Void
    ) -> any PlaybackSettingsObserverHandle {
        guard let playback else { return PlaybackSettingsObserverHandleBox(cancelAction: nil) }
        let handle = playback.addObserver { event in
            switch event {
            case .assetChanged(let url):
                callback(.assetChanged(url: url))
            case .stateChanged(let state):
                callback(.stateChanged(state))
            case .timeChanged(let currentTime, _):
                callback(.timeChanged(currentTime))
            case .durationChanged(let duration):
                callback(.durationChanged(duration))
            default:
                break
            }
        }
        return PlaybackSettingsObserverHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `PlaybackProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class PlaybackSettingsObserverHandleBox: PlaybackSettingsObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}