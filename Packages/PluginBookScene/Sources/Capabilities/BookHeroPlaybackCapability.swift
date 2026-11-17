import Foundation
import ProviderPlayback

/// 书籍封面区的播放事件：只关心当前章节变化。
@MainActor
enum BookHeroPlaybackEvent {
    case assetChanged(URL?)
}

/// 书籍封面区监听句柄。
@MainActor
protocol BookHeroPlaybackObserverHandle: AnyObject {
    /// 停止接收后续事件。重复调用无副作用。
    func cancel()
}

/// 书籍封面区所需的最小播放能力。
@MainActor
protocol BookHeroPlaybackCapability: AnyObject {
    /// 当前播放章节；无播放时为 `nil`。
    var currentURL: URL? { get }

    /// 订阅章节变化；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (BookHeroPlaybackEvent) -> Void
    ) -> any BookHeroPlaybackObserverHandle
}

/// 将内核 `PlaybackProviding` 收窄为书籍封面区的播放能力。
@MainActor
final class BookHeroPlaybackCapabilityAdapter: BookHeroPlaybackCapability {
    /// `weak` 持有 Provider：Provider 可能已被 unregister，此时退化为「无播放」。
    private weak var playback: (any PlaybackProviding)?

    init(playback: (any PlaybackProviding)?) {
        self.playback = playback
    }

    var currentURL: URL? { playback?.currentURL }

    @discardableResult
    func addObserver(
        _ callback: @escaping (BookHeroPlaybackEvent) -> Void
    ) -> any BookHeroPlaybackObserverHandle {
        guard let playback else { return BookHeroPlaybackHandleBox(cancelAction: nil) }
        let handle = playback.addObserver { event in
            guard case let .assetChanged(url) = event else { return }
            callback(.assetChanged(url))
        }
        return BookHeroPlaybackHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核句柄适配为本插件句柄类型，避免 Provider 句柄类型泄漏到能力协议之外。
@MainActor
private final class BookHeroPlaybackHandleBox: BookHeroPlaybackObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}
