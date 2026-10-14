import Foundation
import ProviderPlayback

/// 有声书库播放事件：只保留网格与观察者关心的「当前章节」语义。
@MainActor
enum BookLibraryPlaybackEvent {
    /// 当前播放文件变化；`nil` 表示无播放。
    case assetChanged(url: URL?)
}

/// 有声书库播放监听句柄。
@MainActor
protocol BookLibraryPlaybackObserverHandle: AnyObject {
    /// 停止接收后续播放变更通知。重复调用无副作用。
    func cancel()
}

/// 有声书库网格所需的最小播放能力。
///
/// 内核 `PlaybackProviding` 包含 `pause` / `seek` / `next` / `setPlayMode` 等
/// 大量本插件不使用的控制能力；网格只做两件事——播放指定章节、观察当前
/// 播放文件变化，故在此收窄到最小写入 + 一个事件。
@MainActor
protocol BookLibraryPlaybackCapability: AnyObject {
    /// 当前播放文件；无播放时为 `nil`。
    var currentURL: URL? { get }

    /// 播放指定文件；`startTime` 为 `nil` 时从头播放。
    func play(_ url: URL, startTime: TimeInterval?) async

    /// 订阅当前播放文件变更；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (BookLibraryPlaybackEvent) -> Void
    ) -> any BookLibraryPlaybackObserverHandle
}

/// 将内核 `PlaybackProviding` 收窄为有声书库网格的播放能力。
@MainActor
final class BookLibraryPlaybackCapabilityAdapter: BookLibraryPlaybackCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力应退化为「无播放」而非延长其生命周期。
    private weak var playback: (any PlaybackProviding)?

    init(playback: (any PlaybackProviding)?) {
        self.playback = playback
    }

    var currentURL: URL? { playback?.currentURL }

    func play(_ url: URL, startTime: TimeInterval?) async {
        await playback?.play(url, startTime: startTime)
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (BookLibraryPlaybackEvent) -> Void
    ) -> any BookLibraryPlaybackObserverHandle {
        guard let playback else { return BookLibraryPlaybackObserverHandleBox(cancelAction: nil) }
        let handle = playback.addObserver { event in
            guard case .assetChanged(let url) = event else { return }
            callback(.assetChanged(url: url))
        }
        return BookLibraryPlaybackObserverHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `PlaybackProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class BookLibraryPlaybackObserverHandleBox: BookLibraryPlaybackObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}