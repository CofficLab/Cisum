import Foundation
import ProviderVideo
import SwiftUI

/// 播放引擎的抽象。
///
/// 引擎负责「把一个文件播出来」这件事本身：解码、画面输出、播放控制。
/// 上层的 `VideoPlaybackProviding` 只关心状态与事件，不关心底下是 mpv、
/// VideoToolbox 还是系统 AVPlayer。
@MainActor
protocol VideoEngine: AnyObject {
    /// 当前状态。
    var state: VideoPlaybackState { get }
    /// 当前载入的资源。
    var currentURL: URL? { get }
    /// 播放位置（秒）。
    var currentTime: TimeInterval { get }
    /// 媒体时长（秒）。
    var duration: TimeInterval { get }
    /// 倍速。
    var rate: Float { get }
    /// 事件回调。
    var onEvent: ((VideoPlaybackEvent) -> Void)? { get set }

    /// 载入资源。
    func load(_ url: URL, startTime: TimeInterval?)
    /// 播放。
    func play()
    /// 暂停。
    func pause()
    /// 跳转。
    func seek(to time: TimeInterval)
    /// 停止并释放。
    func stop()
    /// 设置倍速。
    func setRate(_ rate: Float)
    /// 构造画面视图。
    func makeView() -> AnyView
}
