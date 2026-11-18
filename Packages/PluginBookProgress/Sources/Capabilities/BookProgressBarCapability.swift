import Foundation
import ProviderBook
import ProviderPlayback

/// 书籍进度条的播放事件。
@MainActor
enum BookProgressBarEvent {
    case timeChanged(TimeInterval)
    case durationChanged(TimeInterval)
    case assetChanged
    case stateChanged(PlaybackStatus)
}

/// 书籍进度条监听句柄。
@MainActor
protocol BookProgressBarObserverHandle: AnyObject {
    /// 停止接收后续事件。重复调用无副作用。
    func cancel()
}

/// 书籍进度条所需的最小播放能力。
///
/// 与持久化用的 `BookProgressPlaybackCapability` 分开：进度条只关心播放位置、
/// 时长与下载态，主按钮/章节导航由 `PluginBookControlButtons` 独立负责。
@MainActor
protocol BookProgressBarCapability: AnyObject {
    /// 当前播放位置（秒）。
    var currentTime: TimeInterval { get }

    /// 当前资源时长（秒）；未知时为 0。
    var duration: TimeInterval { get }

    /// 当前播放状态。
    var state: PlaybackStatus { get }

    /// 当前播放文件是否属于有声书库。
    ///
    /// 切场景不会重置引擎，音乐曲目可能留在 `currentURL`；
    /// 有声书进度条只在播放书籍章节时才有意义。
    var isCurrentAssetBook: Bool { get }

    /// 跳转到指定时间点（秒）。
    func seek(toTime time: TimeInterval)

    /// 订阅进度条相关事件；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (BookProgressBarEvent) -> Void
    ) -> any BookProgressBarObserverHandle
}

/// 将内核 `PlaybackProviding` 收窄为书籍进度条的播放能力。
@MainActor
final class BookProgressBarCapabilityAdapter: BookProgressBarCapability {
    /// `weak` 持有 Provider：Provider 可能已被 unregister，此时退化为「无播放」。
    private weak var playback: (any PlaybackProviding)?
    private weak var books: (any BookDatabaseProviding)?

    init(playback: (any PlaybackProviding)?, books: (any BookDatabaseProviding)? = nil) {
        self.playback = playback
        self.books = books
    }

    var currentTime: TimeInterval { playback?.currentTime ?? 0 }
    var duration: TimeInterval { playback?.duration ?? 0 }
    var state: PlaybackStatus { playback?.state ?? .idle }

    var isCurrentAssetBook: Bool {
        guard let asset = playback?.currentURL, let disk = books?.bookDisk else { return false }
        let diskPath = Self.stablePath(for: disk)
        let assetPath = Self.stablePath(for: asset)
        let prefix = diskPath.hasSuffix("/") ? diskPath : diskPath + "/"
        return assetPath == diskPath || assetPath.hasPrefix(prefix)
    }

    func seek(toTime time: TimeInterval) {
        guard isCurrentAssetBook else { return }
        playback?.seek(toTime: time)
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (BookProgressBarEvent) -> Void
    ) -> any BookProgressBarObserverHandle {
        guard let playback else { return BookProgressBarHandleBox(cancelAction: nil) }
        let handle = playback.addObserver { event in
            switch event {
            case let .timeChanged(currentTime, _):
                callback(.timeChanged(currentTime))
            case let .durationChanged(duration):
                callback(.durationChanged(duration))
            case .assetChanged:
                callback(.assetChanged)
            case let .stateChanged(state):
                callback(.stateChanged(state))
            default:
                break
            }
        }
        return BookProgressBarHandleBox(cancelAction: handle.cancel)
    }

    private static func stablePath(for url: URL) -> String {
        if FileManager.default.fileExists(atPath: url.path) {
            return url.resolvingSymlinksInPath().standardizedFileURL.path
        }
        return url.standardizedFileURL.path
    }
}

/// 将内核句柄适配为本插件句柄类型，避免 Provider 句柄类型泄漏到能力协议之外。
@MainActor
private final class BookProgressBarHandleBox: BookProgressBarObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}
