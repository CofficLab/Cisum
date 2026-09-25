import ProviderPlayback
import Foundation
import MagicKit

/// 音频自动下载所需的最小播放能力。
///
/// ViewModel 只读取当前播放资产；播放 Provider 的解析与适配由插件入口完成。
@MainActor
protocol AudioDownloadPlaybackCapability: AnyObject {
    var currentURL: URL? { get }
}

/// 将内核播放 Provider 收窄成自动下载能力。
@MainActor
final class AudioDownloadPlaybackCapabilityAdapter: AudioDownloadPlaybackCapability, SuperLog {
    nonisolated static let verbose = false

    private weak var playback: (any PlaybackProviding)?

    init(playback: any PlaybackProviding) {
        self.playback = playback
    }

    var currentURL: URL? { playback?.currentURL }
}