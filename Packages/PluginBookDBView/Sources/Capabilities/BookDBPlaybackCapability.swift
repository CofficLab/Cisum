import Foundation
import OSLog
import ProviderPlayback
import MagicKit

/// 有声书库需要的最小播放能力。
///
/// ViewModel 只依赖这条能力边界，不直接依赖 Kernel 或 `PlaybackProviding`；
/// 具体 Adapter 由 `BookDBViewPlugin` 在生命周期组装阶段创建。
@MainActor
protocol BookDBPlaybackCapability: AnyObject {
    func play(_ url: URL, startTime: TimeInterval?) async
}

/// 将内核播放 Provider 适配成有声书库的播放能力。
@MainActor
final class BookDBPlaybackCapabilityAdapter: BookDBPlaybackCapability, SuperLog {
    nonisolated static let verbose = false

    private let playback: any PlaybackProviding

    init(playback: any PlaybackProviding) {
        self.playback = playback
        if Self.verbose { os_log("\(Self.t)🔌 BookDBPlaybackCapabilityAdapter 初始化") }
    }

    func play(_ url: URL, startTime: TimeInterval?) async {
        if Self.verbose { os_log("\(Self.t)▶️ play: \(url.lastPathComponent) @ \(startTime.map { "\($0)s" } ?? "开头")") }
        await playback.play(url, startTime: startTime)
    }
}
