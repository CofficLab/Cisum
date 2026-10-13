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