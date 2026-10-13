import Foundation
import ProviderPlayback

/// 播放封面事件：只保留封面区关心的两种事件。
@MainActor
enum HeroPlaybackEvent {
    /// 当前播放文件变化。
    case assetChanged(url: URL?)
    /// 播放状态变化。
    case stateChanged(PlaybackStatus)
}

/// 播放封面监听句柄。
@MainActor
protocol HeroPlaybackObserverHandle: AnyObject {
    /// 停止接收后续播放事件。重复调用无副作用。
    func cancel()
}

/// 播放封面区所需的最小播放能力。
///
/// 与 `PlaybackProgressCapability` 同源但语义不同：进度条关心「位置与时长」，
/// 封面区关心「当前文件与状态」，两者不应合并成一个含糊的「播放能力」。
@MainActor
protocol HeroPlaybackCapability: AnyObject {
    /// 当前播放文件；无播放时为 `nil`。
    var currentURL: URL? { get }

    /// 当前播放状态。
    var state: PlaybackStatus { get }

    /// 订阅封面相关播放事件；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (HeroPlaybackEvent) -> Void
    ) -> any HeroPlaybackObserverHandle
}

/// 将内核 `PlaybackProviding` 收窄为封面区的播放能力。
@MainActor
final class HeroPlaybackCapabilityAdapter: HeroPlaybackCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「无播放」而非延长其生命周期。
    private weak var playback: (any PlaybackProviding)?

    init(playback: (any PlaybackProviding)?) {
        self.playback = playback
    }

    var currentURL: URL? { playback?.currentURL }
    var state: PlaybackStatus { playback?.state ?? .idle }

    @discardableResult
    func addObserver(
        _ callback: @escaping (HeroPlaybackEvent) -> Void
    ) -> any HeroPlaybackObserverHandle {
        guard let playback else { return HeroPlaybackObserverHandleBox(cancelAction: nil) }
        let handle = playback.addObserver { event in
            switch event {
            case .assetChanged(let url): callback(.assetChanged(url: url))
            case .stateChanged(let state): callback(.stateChanged(state))
            default: break
            }
        }
        return HeroPlaybackObserverHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `PlaybackProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class HeroPlaybackObserverHandleBox: HeroPlaybackObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}