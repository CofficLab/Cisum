import Foundation
import MagicPlayMan
import OSLog
import ProviderPlayback
import MagicKit

/// BookControl 能够发出的最小播放命令边界。
///
/// 这是插件面向 ViewModel 暴露的能力；ViewModel 不依赖 Kernel、
/// `PlaybackProviding` 或 `MagicPlayMan` 具体类型。Adapter 在
/// `BookControlButtonsPlugin` 的 onReady/onEnable 阶段由内核 Provider 组装。
@MainActor
protocol BookControlPlaybackCapability: AnyObject {
    /// 当前播放资源 URL。
    var currentURL: URL? { get }

    /// 当前是否正在播放。
    var isPlaying: Bool { get }

    /// 当前播放模式（顺序/随机/单曲循环等）。
    var playMode: MagicPlayMode { get }

    /// 播放/暂停切换。
    func toggle()

    /// 循环切换播放模式。
    func togglePlayMode()

    /// 播放指定 URL（自动开始播放）。
    func play(_ url: URL, reason: String) async

    /// 完全卸载当前资源并恢复空闲状态。
    func reset(reason: String) async
}

/// 将内核的 `PlaybackProviding` 适配成 BookControl 的播放能力。
@MainActor
final class BookControlPlaybackCapabilityAdapter: BookControlPlaybackCapability, SuperLog {
    nonisolated static let verbose = false

    private let playback: any PlaybackProviding

    init(playback: any PlaybackProviding) {
        self.playback = playback
        if Self.verbose { os_log("\(Self.t)🔌 BookControlPlaybackCapabilityAdapter 初始化") }
    }

    var currentURL: URL? { playback.currentURL }

    var isPlaying: Bool { playback.isPlaying }

    var playMode: MagicPlayMode {
        MagicPlayMode(rawValue: playback.playMode.rawValue) ?? .sequence
    }

    func toggle() {
        if Self.verbose { os_log("\(Self.t)⏯️ toggle") }
        playback.toggle()
    }

    func togglePlayMode() {
        if Self.verbose { os_log("\(Self.t)🔄 切换播放模式") }
        playback.togglePlayMode()
    }

    func play(_ url: URL, reason: String) async {
        if Self.verbose { os_log("\(Self.t)▶️ play(\(reason)): \(url.lastPathComponent)") }
        await playback.play(url)
    }

    func reset(reason: String) async {
        if Self.verbose { os_log("\(Self.t)🔄 reset(\(reason))") }
        await playback.reset()
    }
}
