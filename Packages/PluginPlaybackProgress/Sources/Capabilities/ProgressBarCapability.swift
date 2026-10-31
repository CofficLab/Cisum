import Foundation
import ProviderPlayback

/// 播放进度条事件：保留进度、时长、文件切换与状态变化四类事件。
@MainActor
enum ProgressBarEvent {
    /// 当前播放位置变化。
    case timeChanged(TimeInterval)
    /// 当前音频总时长变化。
    case durationChanged(TimeInterval)
    /// 当前播放文件变化（进度需按新文件重新同步）。
    case assetChanged
    /// 播放状态变化（用于检测下载态以切换进度条显示模式）。
    case stateChanged(PlaybackStatus)
}

/// 播放进度监听句柄。
@MainActor
protocol ProgressBarObserverHandle: AnyObject {
    /// 停止接收后续进度事件。重复调用无副作用。
    func cancel()
}

/// 播放进度条所需的最小播放能力。
///
/// 内核 `PlaybackProviding` 还包含播放控制、收藏、播放模式等大量能力，
/// 进度条只消费「时长快照 + 跳转 + 四类事件」，故在此收窄。
///
/// `state` 用于检测下载态（`.loading(.downloading)`），此时进度条切换为下载进度显示。
@MainActor
protocol ProgressBarCapability: AnyObject {
    /// 当前播放位置（秒）。
    var currentTime: TimeInterval { get }

    /// 当前音频总时长（秒）。
    var duration: TimeInterval { get }

    /// 当前播放状态（用于检测下载态）。
    var state: PlaybackStatus { get }

    /// 跳转到指定时间点（秒）。
    func seek(toTime time: TimeInterval)

    /// 订阅进度相关事件；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (ProgressBarEvent) -> Void
    ) -> any ProgressBarObserverHandle
}

/// 将内核 `PlaybackProviding` 收窄为进度条的最小能力。
@MainActor
final class ProgressBarCapabilityAdapter: ProgressBarCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「时长归零」而非延长其生命周期。
    private weak var playback: (any PlaybackProviding)?

    init(playback: (any PlaybackProviding)?) {
        self.playback = playback
    }

    var currentTime: TimeInterval { playback?.currentTime ?? 0 }
    var duration: TimeInterval { playback?.duration ?? 0 }
    var state: PlaybackStatus { playback?.state ?? .idle }

    func seek(toTime time: TimeInterval) {
        playback?.seek(toTime: time)
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (ProgressBarEvent) -> Void
    ) -> any ProgressBarObserverHandle {
        guard let playback else { return ProgressBarObserverHandleBox(cancelAction: nil) }
        let handle = playback.addObserver { event in
            switch event {
            case .timeChanged(let currentTime, _):
                // 内核同时携带 progress 百分比；进度条按秒工作，不消费该载荷。
                callback(.timeChanged(currentTime))
            case .durationChanged(let duration):
                callback(.durationChanged(duration))
            case .assetChanged:
                // 内核携带新文件 URL；进度条只需知道「需重新同步」，故剥除载荷。
                callback(.assetChanged)
            case .stateChanged(let state):
                // 转发状态变化，用于检测下载态以切换进度条显示模式。
                callback(.stateChanged(state))
            default:
                break
            }
        }
        return ProgressBarObserverHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `PlaybackProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class ProgressBarObserverHandleBox: ProgressBarObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}