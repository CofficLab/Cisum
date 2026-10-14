import Foundation
import ProviderPlayback

/// 播放模式事件：只保留模式变更一种。
@MainActor
enum BookPlayModeEvent {
    /// 播放模式变更。
    case playModeChanged(PlaybackMode)
}

/// 播放模式监听句柄。
@MainActor
protocol BookPlayModeObserverHandle: AnyObject {
    /// 停止接收后续播放模式变更通知。重复调用无副作用。
    func cancel()
}

/// 书籍播放模式按钮所需的最小播放能力。
///
/// 内核 `PlaybackProviding` 的播放控制、收藏、进度等能力本插件均不消费，
/// 只保留「读当前模式 + 设置模式 + 模式变更事件」——这是播放模式按钮的全部职责。
@MainActor
protocol BookPlayModeCapability: AnyObject {
    /// 当前播放模式。
    var playMode: PlaybackMode { get }

    /// 设置播放模式。
    func setPlayMode(_ mode: PlaybackMode)

    /// 订阅播放模式变更；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (BookPlayModeEvent) -> Void
    ) -> any BookPlayModeObserverHandle
}

/// 将内核 `PlaybackProviding` 收窄为播放模式按钮的最小能力。
@MainActor
final class BookPlayModeCapabilityAdapter: BookPlayModeCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「默认顺序播放」而非延长其生命周期。
    private weak var playback: (any PlaybackProviding)?

    init(playback: (any PlaybackProviding)?) {
        self.playback = playback
    }

    var playMode: PlaybackMode { playback?.playMode ?? .sequence }

    func setPlayMode(_ mode: PlaybackMode) {
        playback?.setPlayMode(mode)
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (BookPlayModeEvent) -> Void
    ) -> any BookPlayModeObserverHandle {
        guard let playback else { return BookPlayModeHandleBox(cancelAction: nil) }
        let handle = playback.addObserver { event in
            guard case let .playModeChanged(mode) = event else { return }
            callback(.playModeChanged(mode))
        }
        return BookPlayModeHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `PlaybackProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class BookPlayModeHandleBox: BookPlayModeObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}