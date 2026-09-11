import Foundation
import OSLog
import ProviderPlayback
import MagicKit

/// BookProgress 能够发出的最小播放命令边界。
///
/// 这是插件面向 ViewModel 暴露的能力；ViewModel 不依赖 Kernel、
/// `PlaybackProviding` 或 `MagicPlayMan` 具体类型。Adapter 在
/// `BookProgressPlugin` 的 onReady/onEnable 阶段由内核 Provider 组装。
@MainActor
protocol BookProgressPlaybackCapability: AnyObject {
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
}

/// 将内核的 `PlaybackProviding` 适配成 BookProgress 的播放能力。
@MainActor
final class BookProgressPlaybackCapabilityAdapter: BookProgressPlaybackCapability, SuperLog {
    nonisolated static let verbose = false

    private let playback: any PlaybackProviding

    init(playback: any PlaybackProviding) {
        self.playback = playback
        if Self.verbose { os_log("\(Self.t)🔌 BookProgressPlaybackCapabilityAdapter 初始化") }
    }

    var currentAsset: URL? { playback.currentURL }

    var state: PlaybackStatus { playback.state }

    var currentTime: TimeInterval { playback.currentTime }

    func play(_ url: URL, autoPlay: Bool, startTime: TimeInterval, reason: String) async {
        if Self.verbose { os_log("\(Self.t)▶️ play(\(reason)): \(url.lastPathComponent) @ \(startTime)s") }
        await playback.play(url, startTime: startTime)
    }

    func seek(to time: TimeInterval) {
        if Self.verbose { os_log("\(Self.t)⏩ seek -> \(time)s") }
        playback.seek(toTime: time)
    }
}
