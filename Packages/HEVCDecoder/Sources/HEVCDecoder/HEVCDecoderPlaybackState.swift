#if os(iOS)
import Foundation

/// HEVC 播放器的播放状态。
///
/// 与 `MagicPlayMan` 的音频播放状态刻意分开：视频播放走 `HEVCDecoder`
/// 自己的解码 / 渲染管线，两边的状态机粒度不同（视频多了 `loading`）。
public enum HEVCDecoderPlaybackState: Equatable {
    case idle
    case loading
    case playing
    case paused
    case finished
    case failed(message: String)
}
#endif
