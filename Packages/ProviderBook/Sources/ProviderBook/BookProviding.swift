import Foundation

/// 书籍库发生外部变化时，Provider 实现通过此事件通知消费者。
@MainActor
public enum BookProvidingEvent {
    case librarySyncing
    case librarySynced
    case libraryChanged(totalCount: Int)
    case libraryDeleted(urls: [URL])
    case librarySorted
    case playbackStateChanged(url: URL?)
    case storageLocationChanged
}

/// 书籍播放状态的跨插件数据传输对象。
public struct BookPlaybackStateDTO: Sendable, Equatable {
    public let currentURL: URL?
    public let time: TimeInterval?

    public init(currentURL: URL?, time: TimeInterval?) {
        self.currentURL = currentURL
        self.time = time
    }
}

@MainActor
public protocol BookProvidingObserverHandle: AnyObject {
    func cancel()
}

/// 书籍库的跨插件读取边界。
///
/// 具体数据库、同步实现和 UI 生命周期属于书籍插件；其他插件只依赖此协议，
/// 通过 Observer 接收变化，不直接导入 `PluginBook`。
@MainActor
public protocol BookProviding: AnyObject {
    var bookDisk: URL? { get }
    var isAvailable: Bool { get }
    func totalCount() async -> Int

    @discardableResult
    func addObserver(
        _ callback: @escaping @Sendable (BookProvidingEvent) -> Void
    ) -> any BookProvidingObserverHandle
}

/// 书籍数据库的跨插件访问边界。
///
/// 数据库容器、同步器和仓库实例由数据层插件持有；View 插件只通过这个
/// Provider 访问书籍数据，避免自行创建 SwiftData 容器。
@MainActor
public protocol BookDatabaseProviding: BookProviding {
    /// 当前数据库根目录。即使书库磁盘尚未配置，数据库根目录也可用。
    var databaseRoot: URL { get }

    /// 返回当前书库中可展示的书籍 DTO。
    func books(reason: String) async -> [BookDTO]

    /// 将已复制到书库的文件/目录同步到数据库。
    func syncImportedItems(_ items: [URL]) async throws

    /// 返回书籍封面原始数据；渲染由 View 插件负责。
    func coverData(for bookURL: URL) async -> Data?

    /// 读取指定书籍的播放状态。
    func playbackState(for bookURL: URL) async -> BookPlaybackStateDTO?

    /// 保存指定书籍的播放状态。
    func savePlaybackState(
        for bookURL: URL,
        currentURL: URL?,
        time: TimeInterval?
    ) async throws

    /// 读取/保存跨设备同步的当前书籍播放偏好。
    func currentBookURL() -> URL?
    func currentBookTime() -> TimeInterval?
    func storeCurrentBookURL(_ url: URL?)
    func storeCurrentBookTime(_ time: TimeInterval)

}

@MainActor
public final class NoopBookProvidingObserverHandle: BookProvidingObserverHandle {
    public init() {}
    public func cancel() {}
}

public extension BookProviding {
    @discardableResult
    func addObserver(
        _ callback: @escaping @Sendable (BookProvidingEvent) -> Void
    ) -> any BookProvidingObserverHandle {
        NoopBookProvidingObserverHandle()
    }
}
