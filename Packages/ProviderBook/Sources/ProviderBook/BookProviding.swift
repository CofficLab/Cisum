import Foundation

/// 书籍库发生外部变化时，Provider 实现通过此事件通知消费者。
@MainActor
public enum BookProvidingEvent {
    case libraryChanged(totalCount: Int)
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
/// Provider 获取已经组装好的仓库，避免自行创建 SwiftData 容器。
@MainActor
public protocol BookDatabaseProviding: BookProviding {
    /// 当前数据库根目录。即使书库磁盘尚未配置，数据库根目录也可用。
    var databaseRoot: URL { get }

    /// 获取数据层缓存的仓库实例。
    func repository() async -> BookRepo?

    /// 存储位置改变后丢弃旧的仓库实例。
    func invalidateRepository()
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
