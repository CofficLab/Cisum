import Foundation
import ProviderPlayback
import MagicKit

/// AudioProgress 能够发出的最小播放命令边界。
///
/// 这是插件面向 ViewModel 暴露的能力；ViewModel 不依赖 Kernel、
/// `PlaybackProviding` 或 `MagicPlayMan` 具体类型。Adapter 在
/// `AudioProgressPlugin` 的 onReady/onEnable 阶段由内核 Provider 组装。
@MainActor
protocol AudioProgressPlaybackCapability: AnyObject {
    /// 当前播放资源 URL。
    var currentAsset: URL? { get }

    /// 当前播放状态。
    var state: PlaybackStatus { get }

    /// 当前播放进度（秒）。
    var currentTime: TimeInterval { get }

    /// 播放指定 URL（可指定起始时间，不自动开始）。
    func play(_ url: URL, autoPlay: Bool, startTime: TimeInterval, reason: String) async

    /// 跳转到指定进度（秒）。恢复文件已被并发加载时，用 seek 补进度而非重载。
    func seek(to time: TimeInterval)

    /// 设置喜欢状态。
    func setLike(_ liked: Bool, reason: String)
}

/// 将内核的 `PlaybackProviding` 适配成 AudioProgress 的播放能力。
@MainActor
final class AudioProgressPlaybackCapabilityAdapter: AudioProgressPlaybackCapability, SuperLog {
    nonisolated static let verbose = false

    private let playback: any PlaybackProviding

    init(playback: any PlaybackProviding) {
        self.playback = playback
    }

    var currentAsset: URL? { playback.currentURL }

    var state: PlaybackStatus { playback.state }

    var currentTime: TimeInterval { playback.currentTime }

    func play(_ url: URL, autoPlay: Bool, startTime: TimeInterval, reason: String) async {
        await playback.play(url, startTime: startTime)
    }

    func seek(to time: TimeInterval) {
        playback.seek(toTime: time)
    }

    func setLike(_ liked: Bool, reason: String) {
        let isCurrentlyLiked = playback.currentURL.map { playback.likedAssets.contains($0) } ?? false
        if isCurrentlyLiked != liked {
            playback.toggleCurrentLike()
        }
    }
}
