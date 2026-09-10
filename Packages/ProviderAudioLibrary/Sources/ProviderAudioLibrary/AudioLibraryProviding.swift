import Foundation

public enum AudioLibraryProvidingError: Error, Sendable {
    case unavailable
}

/// 音频库发生变化时对外发布的领域事件。
///
/// 事件只描述跨插件可观察的事实，不暴露 SwiftData、NotificationCenter
/// 或任何具体仓库类型。
@MainActor
public enum AudioLibraryProvidingEvent {
    case syncing
    case synced(totalCount: Int)
    case updated(totalCount: Int)
    case deleted(urls: [URL], totalCount: Int)
    case sorting
    case sortCompleted
}

@MainActor
public protocol AudioLibraryProvidingObserverHandle: AnyObject {
    func cancel()
}

/// 音频库能力协议。
///
/// Kernel 只定义 AudioDB 所需的抽象能力，不依赖 `AudioRepo` 或任何具体
/// 音频插件模块。具体的音频插件可以在 `onBoot` 阶段注册实现。
@MainActor
public protocol AudioLibraryProviding: AnyObject, Sendable {
    /// 当前音频文件所在的目录。
    var audioDisk: URL? { get }

    /// 当前实现支持导入的文件扩展名。
    var supportedExtensions: [String] { get }

    /// 音频库是否已准备好访问。
    var isAvailable: Bool { get }

    /// 当前音频库中的项目数量。
    func totalCount() async -> Int

    /// 按稳定播放顺序读取音频 URL。
    func allURLs(reason: String) async -> [URL]

    /// 分页读取音频 URL。
    func urls(offset: Int, limit: Int, reason: String) async -> [URL]

    /// 判断 URL 是否存在于音频库中。
    func contains(_ url: URL) async -> Bool

    /// 删除音频文件及其索引记录。
    func delete(urls: [URL], verbose: Bool) async throws

    /// 将文件系统扫描结果同步到音频库。
    func sync(urls: [URL], verbose: Bool, isFirst: Bool) async

    /// 调整播放顺序。
    func sort(url: URL?, reason: String) async

    /// 随机调整播放顺序。
    func sortRandom(url: URL?, reason: String, verbose: Bool) async throws

    @discardableResult
    func addObserver(_ callback: @escaping (AudioLibraryProvidingEvent) -> Void) -> any AudioLibraryProvidingObserverHandle
}

public extension AudioLibraryProviding {
    @discardableResult
    func addObserver(_ callback: @escaping (AudioLibraryProvidingEvent) -> Void) -> any AudioLibraryProvidingObserverHandle {
        NoopAudioLibraryProvidingObserverHandle()
    }
}

@MainActor
public final class NoopAudioLibraryProvidingObserverHandle: AudioLibraryProvidingObserverHandle {
    public init() {}
    public func cancel() {}
}
