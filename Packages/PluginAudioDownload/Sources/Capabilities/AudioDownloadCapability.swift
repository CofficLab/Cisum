import Foundation
import ProviderPlayback

/// 音频自动下载关心的播放事件：只有「当前文件变化」。
@MainActor
enum AudioDownloadEvent {
    /// 当前播放文件变化（`nil` 表示无播放）。
    case assetChanged(URL?)
}

/// 播放监听句柄。
@MainActor
protocol AudioDownloadObserverHandle: AnyObject {
    /// 停止接收后续播放文件变更通知。重复调用无副作用。
    func cancel()
}

/// 音频自动下载所需的最小播放能力。
///
/// 下载器只关心「当前文件及其是否需要预下载」，不消费播放控制、进度、
/// 收藏等其余能力。
@MainActor
protocol AudioDownloadCapability: AnyObject {
    /// 当前播放文件；无播放时为 `nil`。
    var currentURL: URL? { get }

    /// 订阅当前文件变更；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioDownloadEvent) -> Void
    ) -> any AudioDownloadObserverHandle
}

/// 将内核 `PlaybackProviding` 收窄为音频自动下载的播放能力。
@MainActor
final class AudioDownloadCapabilityAdapter: AudioDownloadCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「无播放」而非延长其生命周期。
    private weak var playback: (any PlaybackProviding)?

    init(playback: (any PlaybackProviding)?) {
        self.playback = playback
    }

    var currentURL: URL? { playback?.currentURL }

    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioDownloadEvent) -> Void
    ) -> any AudioDownloadObserverHandle {
        guard let playback else { return AudioDownloadHandleBox(cancelAction: nil) }
        let handle = playback.addObserver { event in
            guard case let .assetChanged(url) = event else { return }
            callback(.assetChanged(url))
        }
        return AudioDownloadHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `PlaybackProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class AudioDownloadHandleBox: AudioDownloadObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}