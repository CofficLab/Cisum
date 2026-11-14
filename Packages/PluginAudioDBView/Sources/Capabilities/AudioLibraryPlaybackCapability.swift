import Foundation
import ProviderPlayback

/// 音频库播放事件：只保留列表关心的「当前播放文件」语义。
@MainActor
enum AudioLibraryPlaybackEvent {
    /// 当前播放文件变化；`nil` 表示无播放。
    case assetChanged(url: URL?)
}

/// 音频库播放监听句柄。
@MainActor
protocol AudioLibraryPlaybackObserverHandle: AnyObject {
    /// 停止接收后续播放变更通知。重复调用无副作用。
    func cancel()
}

/// 音乐库列表所需的最小播放能力。
///
/// 内核 `PlaybackProviding` 包含 `pause` / `seek` / `next` / `setPlayMode` 等
/// 大量本插件不使用的控制能力；列表只做两件事——播放指定文件、重置播放、
/// 观察当前播放文件变化，故在此收窄。
@MainActor
protocol AudioLibraryPlaybackCapability: AnyObject {
    /// 当前播放文件；无播放时为 `nil`。
    var currentURL: URL? { get }

    /// 从头播放指定文件。
    func play(_ url: URL) async

    /// 加载指定文件但**不自动播放**。
    ///
    /// 与 `play` 的区别：加载后播放器持有该资源（`currentURL` 有值、封面与
    /// 标题可见），但不会开始出声。用于「仓库有文件却没有任何当前曲目」时的
    /// 自动兜底——只补齐展示态，不替用户决定开始播放。
    func load(_ url: URL) async

    /// 重置播放状态（删除文件后需要停止对已删文件的播放）。
    func reset() async

    /// 订阅当前播放文件变更；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioLibraryPlaybackEvent) -> Void
    ) -> any AudioLibraryPlaybackObserverHandle
}

/// 将内核 `PlaybackProviding` 收窄为音乐库列表的播放能力。
@MainActor
final class AudioLibraryPlaybackCapabilityAdapter: AudioLibraryPlaybackCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力应退化为「无播放」而非延长其生命周期。
    private weak var playback: (any PlaybackProviding)?

    init(playback: (any PlaybackProviding)?) {
        self.playback = playback
    }

    var currentURL: URL? { playback?.currentURL }

    func play(_ url: URL) async {
        await playback?.play(url)
    }

    /// 加载但不自动播放。
    ///
    /// 内核的 `play(_:startTime:)` 在 `PlaybackProvider` 内部走
    /// `autoPlay: false`：资源被装入播放器（`currentURL` 有值），但不会出声。
    /// 这正是「补齐当前曲目展示态、但不替用户决定开始播放」所需的语义。
    func load(_ url: URL) async {
        await playback?.play(url, startTime: nil)
    }

    func reset() async {
        await playback?.reset()
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioLibraryPlaybackEvent) -> Void
    ) -> any AudioLibraryPlaybackObserverHandle {
        guard let playback else { return AudioLibraryPlaybackObserverHandleBox(cancelAction: nil) }
        let handle = playback.addObserver { event in
            guard case .assetChanged(let url) = event else { return }
            callback(.assetChanged(url: url))
        }
        return AudioLibraryPlaybackObserverHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `PlaybackProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class AudioLibraryPlaybackObserverHandleBox: AudioLibraryPlaybackObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}