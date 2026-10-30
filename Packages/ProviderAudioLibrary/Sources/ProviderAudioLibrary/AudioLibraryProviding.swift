import Foundation
import KitEventObservation

public enum AudioLibraryProvidingError: Error, Sendable {
    case unavailable
}

/// 音频库发生变化时对外发布的领域事件。
///
/// 事件只描述跨插件可观察的事实，不暴露 SwiftData、NotificationCenter
/// 或任何具体仓库类型。
public enum AudioLibraryProvidingEvent: Sendable {
    case syncing
    case synced(totalCount: Int)
    case updated(totalCount: Int)
    case deleted(urls: [URL], totalCount: Int)
    /// The repository has been successfully scanned or changed and contains no indexed audio.
    case repositoryEmpty
    /// The backing storage location changed and callers should re-check availability.
    case repositoryAvailabilityChanged
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

    /// 音乐仓库是否确认为空。
    ///
    /// 只有在**完成过一次扫描**之后才有结论：还没扫过的仓库同样「数不出文件」，
    /// 那是「还不知道」，不是「是空的」。数据层因此区分三态——未知 / 空 / 非空，
    /// 消费方（如空仓库引导、「更多」按钮的提示）直接读这个结论，不必各自
    /// 重新解释一遍计数。
    var isRepositoryEmpty: Bool { get }

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

    /// Observers receive future library events. If the provider has already
    /// confirmed an empty repository, the empty event is replayed immediately.
    @discardableResult
    func addObserver(_ callback: @escaping (AudioLibraryProvidingEvent) -> Void) -> any AudioLibraryProvidingObserverHandle
}

public extension AudioLibraryProviding {
    /// 默认不认为仓库为空：不知道 ≠ 是空的。
    ///
    /// 不跟踪扫描状态的实现方（如测试替身）会落到这个默认值——引导不出现，
    /// 而不是误报「仓库是空的」。
    var isRepositoryEmpty: Bool { false }

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

extension EventObserverHandle: AudioLibraryProvidingObserverHandle {}
