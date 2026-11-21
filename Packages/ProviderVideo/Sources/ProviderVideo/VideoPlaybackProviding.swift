import Foundation
import SwiftUI

/// 视频播放状态。
public enum VideoPlaybackState: Equatable, Sendable {
    /// 没有载入任何视频。
    case idle
    /// 正在准备资源。
    case loading
    /// 正在播放。
    case playing
    /// 已暂停。
    case paused
    /// 播放结束。
    case finished
    /// 播放失败。
    case failed(String)

    /// 是否正在播放。
    public var isPlaying: Bool { self == .playing }
}

/// 视频播放事件。
@MainActor
public enum VideoPlaybackEvent: Sendable {
    /// 状态变化。
    case stateChanged(VideoPlaybackState)
    /// 载入的资源变化。
    case assetChanged(URL?)
    /// 播放位置变化。
    case timeChanged(currentTime: TimeInterval, duration: TimeInterval, progress: Double)
    /// 倍速变化。
    case rateChanged(Float)
    /// 播放自然结束。
    case didFinish(URL)
}

/// 视频播放事件的观察句柄。
@MainActor
public protocol VideoPlaybackObserverHandle: AnyObject {
    func cancel()
}

/// 视频播放能力。
///
/// 与 `ProviderPlayback.PlaybackProviding`（音频）分开：视频场景使用
/// 独立的引擎（macOS 走 mpv，iOS 走 VideoToolbox），不与音乐场景的
/// 播放队列互相干扰。
@MainActor
public protocol VideoPlaybackProviding: AnyObject {
    /// 当前状态。
    var state: VideoPlaybackState { get }
    /// 当前载入的资源。
    var currentURL: URL? { get }
    /// 播放位置（秒）。
    var currentTime: TimeInterval { get }
    /// 媒体时长（秒）。
    var duration: TimeInterval { get }
    /// 播放进度（0...1）。
    var progress: Double { get }
    /// 倍速。
    var rate: Float { get }
    /// 是否已载入资源。
    var hasAsset: Bool { get }

    /// 播放指定视频。
    func play(_ url: URL, startTime: TimeInterval?)
    /// 暂停。
    func pause()
    /// 播放 / 暂停切换。
    func toggle()
    /// 停止并释放资源。
    func stop()
    /// 跳转到指定位置。
    func seek(toTime time: TimeInterval)
    /// 设置倍速。
    func setRate(_ rate: Float)

    /// 构造播放器画面视图。
    func makePlayerView() -> AnyView

    @discardableResult
    func addObserver(_ callback: @escaping (VideoPlaybackEvent) -> Void) -> any VideoPlaybackObserverHandle
}
