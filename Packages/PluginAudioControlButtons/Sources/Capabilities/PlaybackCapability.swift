import Foundation
import MagicPlayMan

/// ControlButtons 能够发出的最小播放命令边界。
///
/// 这是插件面向 ViewModel 暴露的能力；ViewModel 不依赖 Kernel、
/// `PlaybackProviding` 或 `MagicPlayMan` 具体类型。Adapter 在
/// `AudioControlButtonsPlugin` 的 onReady 阶段由内核 Provider 组装。
@MainActor
protocol PlaybackCapability: AnyObject {
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

    /// 播放指定 URL。
    func play(_ url: URL) async

    /// 完全卸载当前资源并恢复空闲状态。
    func reset() async
}
