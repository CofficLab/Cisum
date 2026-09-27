import AVFoundation
import Combine
import Foundation
import ProviderPlayback
import CisumUIComponents
import LumiUI
import MagicKit
import MediaPlayer
import OSLog
import SwiftUI

/// 媒体播放管理器
/// 提供音频和视频播放功能，支持播放模式切换、喜欢状态管理等
@MainActor
public class MagicPlayMan: ObservableObject, SuperLog {
    /// 日志标识符
    public nonisolated static let emoji = "🎧"

    /// 是否启用详细日志输出
    public nonisolated static let verbose = false

    /// AVPlayer 播放器实例
    internal let _player = AVPlayer()

    /// 时间观察者引用，用于监听播放进度
    internal var timeObserver: Any?

    /// 当前播放信息字典，用于系统媒体控制中心
    internal var nowPlayingInfo: [String: Any] = [:]

    /// 资源缓存管理器
    internal var cache: AssetCache?

    /// 是否启用详细日志输出（实例级别）
    internal var verbose: Bool = false

    /// 日志记录器
    internal let logger = MagicLogger()

    /// Combine 订阅集合，用于管理事件订阅
    public var cancellables = Set<AnyCancellable>()

    /// 外部事件订阅集合，按订阅者 ID 管理以支持精确取消订阅
    internal var eventCancellables: [UUID: Set<AnyCancellable>] = [:]

    /// 当前下载任务
    public private(set) var downloadTask: URLSessionDataTask?

    /// 播放相关的事件发布者
    public private(set) lazy var events = PlaybackEvents()

    /// 当前下载监听器引用
    private(set) var currentDownloadObservers: (asset: URL, progressObserver: AnyCancellable, finishObserver: AnyCancellable)?

    private var playRequestGeneration: UInt64 = 0

    /// 本地化配置
    public var localization = Localization(locale: .current)

    /// 默认封面图，用于在音频缩略图无法获得时显示
    public var defaultArtwork: Image?

    /// 默认封面图构建器，支持自定义视图作为默认封面
    public var defaultArtworkBuilder: (() -> any View)?

    /// 当前播放模式（顺序、随机、单曲循环等）
    @Published public private(set) var playMode: PlaybackMode = .sequence

    /// 当前播放的资源 URL
    @Published public private(set) var currentURL: URL?

    /// 当前播放状态（空闲、播放中、暂停、加载中等）
    @Published public private(set) var state: PlaybackState = .idle

    /// 当前播放时间（秒）
    @Published public private(set) var currentTime: TimeInterval = 0

    /// 媒体总时长（秒）
    @Published public private(set) var duration: TimeInterval = 0

    /// 播放进度（0-1）
    @Published public private(set) var progress: Double = 0

    /// 已喜欢的资源 URL 集合
    @Published public private(set) var likedAssets: Set<URL> = []
}

enum MagicPlayManPlaybackTimePolicy {
    static func normalizedDuration(_ duration: TimeInterval) -> TimeInterval {
        guard duration.isFinite else { return 0 }
        return max(duration, 0)
    }

    static func normalizedUnitProgress(_ progress: Double) -> Double {
        min(max(progress.isFinite ? progress : 0, 0), 1)
    }

    static func normalizedCurrentTime(_ time: TimeInterval, duration: TimeInterval? = nil) -> TimeInterval {
        guard time.isFinite else { return 0 }
        let currentTime = max(time, 0)

        guard let duration, duration.isFinite, duration > 0 else {
            return currentTime
        }

        return min(currentTime, duration)
    }

    static func normalizedProgress(currentTime: TimeInterval, duration: TimeInterval) -> Double {
        guard currentTime.isFinite, duration.isFinite, duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    static func shouldRestartFromBeginning(currentTime: TimeInterval, duration: TimeInterval) -> Bool {
        guard currentTime.isFinite, duration.isFinite, duration > 0 else { return false }
        return currentTime >= duration
    }
}

// MARK: - Setter

extension MagicPlayMan {
    /// 设置当前播放时间
    /// - Parameter
    ///   - time: 播放时间（秒）
    ///   - reason: 状态变更原因（用于日志记录）
    @MainActor
    func setCurrentTime(_ time: TimeInterval, reason: String) {
        let time = MagicPlayManPlaybackTimePolicy.normalizedCurrentTime(time, duration: duration)

        if verbose && false {
            os_log("\(self.t)🕒 (\(reason)) Set current playback time: \(time)s")
        }

        let oldTime = currentTime
        currentTime = time

        // 发送时间更新通知
        if oldTime != time {
            let progress = MagicPlayManPlaybackTimePolicy.normalizedProgress(
                currentTime: time,
                duration: duration
            )
            sendTimeUpdate(currentTime: time, progress: progress)
        }
    }

    /// 设置媒体总时长
    /// - Parameter value: 总时长（秒）
    @MainActor
    func setDuration(_ value: TimeInterval) {
        let value = MagicPlayManPlaybackTimePolicy.normalizedDuration(value)
        let oldDuration = duration
        duration = value

        // 发送时长变更通知
        if oldDuration != value {
            sendDurationChanged(duration: value)
        }
    }

    /// 设置播放进度
    /// - Parameter value: 播放进度（0-1）
    @MainActor
    func setProgress(_ value: Double) {
        let normalizedValue = MagicPlayManPlaybackTimePolicy.normalizedUnitProgress(value)

        // The periodic time observer runs twice per second. Avoid publishing a
        // second change when rounding/normalization leaves progress unchanged;
        // this prevents every observer from invalidating its view for no reason.
        guard abs(progress - normalizedValue) > 0.0001 else { return }
        progress = normalizedValue
    }

    /// 设置已喜欢的资源集合
    /// - Parameter assets: 已喜欢的资源 URL 集合
    @MainActor
    func setLikedAssets(_ assets: Set<URL>) {
        likedAssets = assets
    }

    /// 设置播放状态
    /// - Parameters:
    ///   - state: 新的播放状态
    ///   - reason: 状态变更原因（用于日志记录）
    @MainActor
    internal func setState(_ state: PlaybackState, reason: String) {
        let oldState = self.state
        self.state = state

        if verbose {
            os_log("\(self.t)🍋 (\(reason)) Set playback state to: \(state.stateText)")
        }
        events.onStateChanged.send(state)
        if case let .failed(error) = state {
            events.onPlaybackFailed.send(error)
        }

        // 发送状态变更通知
        let isPlaying = (state == .playing)
        let oldIsPlaying = (oldState == .playing)
        if oldIsPlaying != isPlaying {
            sendStateChanged(isPlaying: isPlaying)
        }
    }

    /// 设置当前播放的资源 URL
    /// - Parameter url: 资源 URL
    @MainActor
    func setCurrentURL(_ url: URL?) {
        let oldURL = currentURL
        currentURL = url

        events.onCurrentURLChanged.send(url)

        // 发送播放资源变更通知
        if oldURL != url {
            sendAssetChanged(asset: url)
        }
    }

    /// 设置播放模式
    /// - Parameter mode: 播放模式
    @MainActor
    func setPlayMode(_ mode: PlaybackMode) {
        playMode = mode

        if verbose {
            os_log("\(self.t)Playback mode changed: \(mode.displayName)")
        }
        events.onPlayModeChanged.send(playMode)
    }

    /// 恢复已持久化的播放模式，不触发播放模式变更事件。
    /// 用于启动或切换场景时同步 UI 状态，避免误触发提示和队列重排。
    @MainActor
    public func restorePlayMode(_ mode: PlaybackMode) {
        playMode = mode
    }

    /// 设置当前下载监听器引用
    /// - Parameter observers: 下载监听器元组（进度观察者和完成观察者）
    @MainActor
    func setCurrentDownloadObservers(_ observers: (asset: URL, progressObserver: AnyCancellable, finishObserver: AnyCancellable)?) {
        currentDownloadObservers?.progressObserver.cancel()
        currentDownloadObservers?.finishObserver.cancel()
        currentDownloadObservers = observers
    }

    @MainActor
    @discardableResult
    func beginPlayRequest() -> UInt64 {
        playRequestGeneration &+= 1
        return playRequestGeneration
    }

    @MainActor
    func isCurrentPlayRequest(_ generation: UInt64) -> Bool {
        playRequestGeneration == generation
    }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    MagicPlayMan.getPreviewView()
        .frame(width: 600)
        .frame(height: 600)
}

#Preview("App - Big Screen") {
    MagicPlayMan.getPreviewView()
        .frame(width: 1200)
        .frame(height: 1200)
}
