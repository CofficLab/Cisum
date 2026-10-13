import Foundation
import ProviderPlayback

/// 播放控制事件：只保留控制按钮组关心的五种事件。
///
/// 内核 `PlaybackProvidingEvent` 还含 `assetChanged` / `timeChanged` /
/// `durationChanged` / `likeStatusChanged` / `snapshotChanged` 等事件，
/// 本插件的 Observer 不消费，故在此剥除。
@MainActor
enum PlaybackControlEvent {
    /// 播放状态变化（含加载中/失败）。
    case stateChanged(PlaybackStatus)
    /// 播放模式变化。
    case playModeChanged(PlaybackMode)
    /// 播放引擎请求上一曲（由远程/媒体键等外部触发）。
    case previousRequested(URL)
    /// 播放引擎请求下一曲。
    case nextRequested(URL)
    /// 导航请求被拒绝。
    case navigationFailed(PlaybackNavigationFailure)
}

/// 播放控制监听句柄。
@MainActor
protocol PlaybackControlObserverHandle: AnyObject {
    /// 停止接收后续播放事件。重复调用无副作用。
    func cancel()
}

/// 播放控制按钮所需的最小播放能力。
///
/// 内核 `PlaybackProviding` 包含 `progress` / `likedAssets` / `hasAsset` 等
/// 本插件不消费的只读快照，以及 `pause` / `seek` / `next` / `previous` /
/// `setPlayMode` 等本插件改由导航能力驱动的控制方法，故在此收窄到：
/// 「上一曲/下一曲由导航能力决定 + 播放模式切换委托引擎」所需最小面。
@MainActor
protocol PlaybackControlCapability: AnyObject {
    /// 当前播放文件；无播放时为 `nil`。
    var currentURL: URL? { get }

    /// 是否正在播放。
    var isPlaying: Bool { get }

    /// 当前播放模式。
    var playMode: PlaybackMode { get }

    /// 播放指定文件。
    func play(_ url: URL) async

    /// 重置播放状态。
    func reset() async

    /// 播放/暂停切换。
    func toggle()

    /// 切换播放模式（顺序 / 单曲 / 随机）。
    func togglePlayMode()

    /// 订阅播放控制相关事件；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (PlaybackControlEvent) -> Void
    ) -> any PlaybackControlObserverHandle
}

/// 将内核 `PlaybackProviding` 收窄为播放控制按钮的播放能力。
@MainActor
final class PlaybackControlCapabilityAdapter: PlaybackControlCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力应退化为「播放不可用」而非延长其生命周期。
    private weak var playback: (any PlaybackProviding)?

    init(playback: (any PlaybackProviding)?) {
        self.playback = playback
    }

    var currentURL: URL? { playback?.currentURL }
    var isPlaying: Bool { playback?.isPlaying ?? false }
    var playMode: PlaybackMode { playback?.playMode ?? .sequence }

    func play(_ url: URL) async {
        await playback?.play(url)
    }

    func reset() async {
        await playback?.reset()
    }

    func toggle() {
        playback?.toggle()
    }

    func togglePlayMode() {
        playback?.togglePlayMode()
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (PlaybackControlEvent) -> Void
    ) -> any PlaybackControlObserverHandle {
        guard let playback else { return PlaybackControlObserverHandleBox(cancelAction: nil) }
        let handle = playback.addObserver { event in
            switch event {
            case .stateChanged(let state):
                callback(.stateChanged(state))
            case .playModeChanged(let mode):
                callback(.playModeChanged(mode))
            case .previousRequested(let asset):
                callback(.previousRequested(asset))
            case .nextRequested(let asset):
                callback(.nextRequested(asset))
            case .navigationFailed(let failure):
                callback(.navigationFailed(failure))
            default:
                break
            }
        }
        return PlaybackControlObserverHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `PlaybackProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class PlaybackControlObserverHandleBox: PlaybackControlObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}