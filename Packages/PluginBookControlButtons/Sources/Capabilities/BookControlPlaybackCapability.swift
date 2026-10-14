import Foundation
import ProviderPlayback

/// 有声书控制事件：只保留控制按钮组关心的四种事件。
@MainActor
enum BookControlPlaybackEvent {
    /// 播放状态变化。
    case stateChanged(PlaybackStatus)
    /// 播放模式变化。
    case playModeChanged(PlaybackMode)
    /// 播放引擎请求上一章。
    case previousRequested(URL)
    /// 播放引擎请求下一章。
    case nextRequested(URL)
}

/// 有声书控制监听句柄。
@MainActor
protocol BookControlPlaybackObserverHandle: AnyObject {
    /// 停止接收后续播放事件。重复调用无副作用。
    func cancel()
}

/// 有声书控制按钮所需的最小播放能力。
///
/// 内核 `PlaybackProviding` 的收藏、进度、跳转等能力本插件不消费；
/// 上一章/下一章的文件选择由书籍章节能力决定，播放按钮只做播放/暂停
/// 与播放模式切换。
@MainActor
protocol BookControlPlaybackCapability: AnyObject {
    /// 是否正在播放。
    var isPlaying: Bool { get }

    /// 当前播放模式。
    var playMode: PlaybackMode { get }

    /// 当前播放文件；无播放时为 `nil`。
    var currentURL: URL? { get }

    /// 播放指定文件；`startTime` 为 `nil` 时从头播放。
    func play(_ url: URL, startTime: TimeInterval?) async

    /// 重置播放状态（章节被删除后需要停止对已删文件的播放）。
    func reset() async

    /// 播放/暂停切换。
    func toggle()

    /// 切换播放模式（顺序 / 单曲 / 随机）。
    func togglePlayMode()

    /// 订阅播放控制相关事件；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (BookControlPlaybackEvent) -> Void
    ) -> any BookControlPlaybackObserverHandle
}

/// 将内核 `PlaybackProviding` 收窄为有声书控制按钮的播放能力。
@MainActor
final class BookControlPlaybackCapabilityAdapter: BookControlPlaybackCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「播放不可用」而非延长其生命周期。
    private weak var playback: (any PlaybackProviding)?

    init(playback: (any PlaybackProviding)?) {
        self.playback = playback
    }

    var isPlaying: Bool { playback?.isPlaying ?? false }
    var playMode: PlaybackMode { playback?.playMode ?? .sequence }
    var currentURL: URL? { playback?.currentURL }

    func play(_ url: URL, startTime: TimeInterval?) async {
        await playback?.play(url, startTime: startTime)
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
        _ callback: @escaping (BookControlPlaybackEvent) -> Void
    ) -> any BookControlPlaybackObserverHandle {
        guard let playback else { return BookControlPlaybackHandleBox(cancelAction: nil) }
        let handle = playback.addObserver { event in
            switch event {
            case .stateChanged(let state): callback(.stateChanged(state))
            case .playModeChanged(let mode): callback(.playModeChanged(mode))
            case .previousRequested(let asset): callback(.previousRequested(asset))
            case .nextRequested(let asset): callback(.nextRequested(asset))
            default: break
            }
        }
        return BookControlPlaybackHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `PlaybackProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class BookControlPlaybackHandleBox: BookControlPlaybackObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}