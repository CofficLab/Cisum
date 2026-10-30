import Foundation
import KitEventObservation
import SwiftUI

/// 播放能力的基础状态。该类型属于 Provider 契约，不依赖具体播放器实现。
public enum PlaybackStatus: Equatable, Sendable {
    case idle
    case loading(LoadingStatus)
    case willPlay
    case playing
    case paused
    case stopped
    case failed(PlaybackFailure)

    public enum LoadingStatus: Equatable, Sendable {
        case connecting
        case preparing
        case buffering
        case downloading(Double)
    }

    public var isPlaying: Bool { self == .playing }

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    public var isDownloading: Bool {
        guard case let .loading(status) = self else { return false }
        if case .downloading = status { return true }
        return false
    }
}

public enum PlaybackFailure: Equatable, Sendable {
    case noAsset
    case invalidAsset
    case networkError(String)
    case playbackError(String)
    case unsupportedFormat(String)
    case invalidURL(String)
    /// iCloud 文件未能下载到本地（超时 / 离线 / 请求被拒）。
    ///
    /// 与 `.networkError` 分开：二者的用户提示与恢复建议不同，
    /// 跨插件传递时不应被合并为普通网络错误。
    case iCloudDownloadFailed(String)
}

/// Provider 对外暴露的播放模式数据。
public enum PlaybackMode: String, CaseIterable, Sendable {
    case sequence
    case loop
    case shuffle
    case repeatAll
}

public enum PlaybackNavigationDirection: Equatable, Sendable {
    case previous
    case next
}

public struct PlaybackNavigationFailure: Equatable, Sendable {
    public let direction: PlaybackNavigationDirection
    public let reason: String

    public init(direction: PlaybackNavigationDirection, reason: String) {
        self.direction = direction
        self.reason = reason
    }
}

/// 播放能力的一致快照，供插件初始同步和测试使用。
public struct PlaybackSnapshot: Equatable, Sendable {
    public let state: PlaybackStatus
    public let currentURL: URL?
    public let currentTime: TimeInterval
    public let duration: TimeInterval
    public let progress: Double
    public let playMode: PlaybackMode
    public let likedAssets: Set<URL>

    public init(
        state: PlaybackStatus,
        currentURL: URL?,
        currentTime: TimeInterval,
        duration: TimeInterval,
        progress: Double,
        playMode: PlaybackMode,
        likedAssets: Set<URL>
    ) {
        self.state = state
        self.currentURL = currentURL
        self.currentTime = currentTime
        self.duration = duration
        self.progress = progress
        self.playMode = playMode
        self.likedAssets = likedAssets
    }

    public var isPlaying: Bool { state.isPlaying }
    public var hasAsset: Bool { currentURL != nil }
}

@MainActor
public enum PlaybackProvidingEvent {
    case snapshotChanged(PlaybackSnapshot)
    case stateChanged(PlaybackStatus)
    case assetChanged(URL?)
    case timeChanged(currentTime: TimeInterval, progress: Double)
    case durationChanged(TimeInterval)
    case playModeChanged(PlaybackMode)
    case likedAssetsChanged(Set<URL>)
    case likeStatusChanged(asset: URL, isLiked: Bool)
    case previousRequested(URL)
    case nextRequested(URL)
    case navigationFailed(PlaybackNavigationFailure)
}

@MainActor
public protocol PlaybackProvidingObserverHandle: AnyObject {
    func cancel()
}

/// 播放视觉能力。播放封面插件只依赖这个抽象，不需要知道底层播放器类型。
@MainActor
public protocol PlaybackMediaProviding: AnyObject {
    func makeMediaView() -> AnyView
    func localizedStateText(for state: PlaybackStatus) -> String
    /// 下载态的**纯文案**标签（不含百分比）。
    ///
    /// 与 `localizedStateText(for:)` 分开：状态文案在下载态下自带百分比
    /// （如「正在下载 14%」），而 Hero 圆环已在中心单独显示百分比，
    /// 底部小字若再带百分比就会出现同一屏两个百分比。
    func localizedDownloadingLabel() -> String
}

public extension PlaybackMediaProviding {
    /// 下载态的纯文案标签（不含百分比）。
    ///
    /// 默认实现从该 provider 自己的下载态状态文案中剥离尾部百分比
    /// （如「正在下载 14%」→「正在下载」），保证与 provider 的本地化语言一致；
    /// 引擎侧持有本地化资源，可覆盖为更精确的取值。
    func localizedDownloadingLabel() -> String {
        let text = localizedStateText(for: .loading(.downloading(0)))
        guard let separator = text.lastIndex(of: " "),
              text[text.index(after: separator)...].hasSuffix("%") else {
            return text
        }
        return String(text[..<separator])
    }
}

/// 播放服务能力协议：定义能力、基础数据和事件，不包含具体实现。
@MainActor
public protocol PlaybackProviding: AnyObject {
    var state: PlaybackStatus { get }
    var currentURL: URL? { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var progress: Double { get }
    var playMode: PlaybackMode { get }
    var likedAssets: Set<URL> { get }
    var isPlaying: Bool { get }
    var hasAsset: Bool { get }
    var snapshot: PlaybackSnapshot { get }

    func play(_ url: URL) async
    func play(_ url: URL, startTime: TimeInterval?) async
    func pause()
    func toggle()
    func seek(toProgress progress: Double)
    func seek(toTime time: TimeInterval)
    func next()
    func previous()
    func setPlayMode(_ mode: PlaybackMode)
    func toggleCurrentLike()
    func reset() async
    func togglePlayMode()

    @discardableResult
    func addObserver(_ callback: @escaping (PlaybackProvidingEvent) -> Void) -> any PlaybackProvidingObserverHandle
}

public extension PlaybackProviding {
    var snapshot: PlaybackSnapshot {
        PlaybackSnapshot(
            state: state,
            currentURL: currentURL,
            currentTime: currentTime,
            duration: duration,
            progress: progress,
            playMode: playMode,
            likedAssets: likedAssets
        )
    }

    func play(_ url: URL, startTime: TimeInterval?) async {
        await play(url)
    }

    func reset() async {}

    @discardableResult
    func addObserver(_ callback: @escaping (PlaybackProvidingEvent) -> Void) -> any PlaybackProvidingObserverHandle {
        NoopPlaybackProvidingObserverHandle()
    }
}

@MainActor
public final class NoopPlaybackProvidingObserverHandle: PlaybackProvidingObserverHandle {
    public init() {}
    public func cancel() {}
}

extension EventObserverHandle: PlaybackProvidingObserverHandle {}
