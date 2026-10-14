import Foundation
import ProviderPlayback

/// Widget 播放事件：Widget 的控制命令通过 Darwin 通知进入，
/// 不订阅播放 Provider 事件，故本能力**不暴露任何事件成员**。
///
/// 标记为「纯命令式」能力：Widget 只发命令、从不读状态，
/// 因此这里没有 `addObserver`。
@MainActor
protocol WidgetPlaybackCapability: AnyObject {
    /// 当前播放文件；无播放时为 `nil`。
    var currentURL: URL? { get }

    /// 当前播放状态。
    var state: PlaybackStatus { get }

    /// 当前播放模式（用于「单曲/列表循环」的边界回绕判断）。
    var playMode: PlaybackMode { get }

    /// 播放指定文件。
    func play(_ url: URL) async

    /// 暂停播放。
    func pause()

    /// 播放/暂停切换。
    func toggle()
}

/// 将内核 `PlaybackProviding` 收窄为 Widget 控制的播放能力。
@MainActor
final class WidgetPlaybackCapabilityAdapter: WidgetPlaybackCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「无播放」而非延长其生命周期。
    private weak var playback: (any PlaybackProviding)?

    init(playback: (any PlaybackProviding)?) {
        self.playback = playback
    }

    var currentURL: URL? { playback?.currentURL }
    var state: PlaybackStatus { playback?.state ?? .idle }
    var playMode: PlaybackMode { playback?.playMode ?? .sequence }

    func play(_ url: URL) async {
        await playback?.play(url)
    }

    func pause() {
        playback?.pause()
    }

    func toggle() {
        playback?.toggle()
    }
}