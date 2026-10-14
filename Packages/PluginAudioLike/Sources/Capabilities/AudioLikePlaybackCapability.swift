import Foundation
import ProviderPlayback

/// 音频喜欢关心的播放事件：只有「喜欢状态」一种。
@MainActor
enum AudioLikePlaybackEvent {
    /// 某文件的喜欢状态变化。
    case likeStatusChanged(asset: URL, isLiked: Bool)
}

/// 喜欢状态监听句柄。
@MainActor
protocol AudioLikePlaybackObserverHandle: AnyObject {
    /// 停止接收后续喜欢状态变更通知。重复调用无副作用。
    func cancel()
}

/// 音频喜欢按钮所需的最小播放能力。
///
/// 与播放相关的其余事件（播放、进度、模式、导航）本插件均不消费；
/// 喜欢按钮只关心「哪个文件的喜欢状态变了」。
@MainActor
protocol AudioLikePlaybackCapability: AnyObject {
    /// 订阅喜欢状态变更；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioLikePlaybackEvent) -> Void
    ) -> any AudioLikePlaybackObserverHandle
}

/// 将内核 `PlaybackProviding` 收窄为音频喜欢的播放能力。
@MainActor
final class AudioLikePlaybackCapabilityAdapter: AudioLikePlaybackCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「收不到喜欢状态变更」而非延长其生命周期。
    private weak var playback: (any PlaybackProviding)?

    init(playback: (any PlaybackProviding)?) {
        self.playback = playback
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioLikePlaybackEvent) -> Void
    ) -> any AudioLikePlaybackObserverHandle {
        guard let playback else { return AudioLikePlaybackHandleBox(cancelAction: nil) }
        let handle = playback.addObserver { event in
            guard case let .likeStatusChanged(asset, isLiked) = event else { return }
            callback(.likeStatusChanged(asset: asset, isLiked: isLiked))
        }
        return AudioLikePlaybackHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `PlaybackProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class AudioLikePlaybackHandleBox: AudioLikePlaybackObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}