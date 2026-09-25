import Foundation

@MainActor
public enum StorageProvidingEvent {
    case locationChanged(StorageLocation?)
    case storageAvailabilityChanged
}

@MainActor
public protocol StorageProvidingObserverHandle: AnyObject {
    func cancel()
}

/// 存储服务能力协议。
///
/// 统一管理应用的持久化存储位置（iCloud / 本地 / 自定义），吸收了旧版
/// `Config` 的存储位置逻辑，以及 `StoragePluginHost` / `AudioPluginHost` /
/// `BookPluginHost` / `WelcomePluginHost` 中所有存储相关的桥接面。
///
/// Kernel 只持有此协议，不依赖任何具体实现或旧版 Host。
///
/// ## 使用示例
///
/// ```swift
/// let root = kernel.resolveProvider((any StorageProviding).self)?.storageRoot
/// try let db = kernel.resolveProvider((any StorageProviding).self)?.databaseFile(name: "audio")
/// kernel.resolveProvider((any StorageProviding).self)?.setStorageLocation(.icloud)
/// ```
@MainActor
public protocol StorageProviding: AnyObject, ObservableObject {
    /// 当前存储位置；尚未配置时为 `nil`。
    var currentStorageLocation: StorageLocation? { get }

    /// 当前存储位置解析出的根 URL；不可用时为 `nil`。
    var storageRoot: URL? { get }

    /// 解析指定存储位置对应的根 URL；不可用时返回 `nil`。
    func storageRoot(for location: StorageLocation) -> URL?

    /// 是否已配置可用存储位置。
    var hasUsableStorageLocation: Bool { get }

    /// iCloud 是否可用（容器可解析且用户已登录）。
    var isICloudStorageAvailable: Bool { get }

    /// 数据库根目录（始终可用，按需创建）。
    var databaseRoot: URL { get }

    /// 在数据库根下创建（或获取）具名数据库文件 URL，按需创建父目录。
    ///
    /// - Parameter name: 数据库逻辑名（会生成 `<name>/<name>.db`）。
    /// - Returns: 数据库文件 URL。
    func databaseFile(name: String) throws -> URL

    /// 获取（或创建）指定插件的专属数据目录：`<databaseRoot>/<pluginID>/`。
    ///
    /// 每个插件用它保存自己的持久化数据（对齐 Lumi `StorageProviding.pluginDataDirectory(for:)`）。
    ///
    /// - Parameter pluginID: 插件 ID。
    /// - Returns: 插件数据目录 URL。
    func pluginDataDirectory(for pluginID: String) -> URL

    /// 设置存储位置并持久化，同时广播变更事件。
    func setStorageLocation(_ location: StorageLocation?)

    /// 清除存储位置配置并广播重置事件。
    func resetStorageLocation()

    @discardableResult
    func addObserver(_ callback: @escaping (StorageProvidingEvent) -> Void) -> any StorageProvidingObserverHandle
}

public extension StorageProviding {
    @discardableResult
    func addObserver(_ callback: @escaping (StorageProvidingEvent) -> Void) -> any StorageProvidingObserverHandle {
        NoopStorageProvidingObserverHandle()
    }
}

@MainActor
public final class NoopStorageProvidingObserverHandle: StorageProvidingObserverHandle {
    public init() {}
    public func cancel() {}
}
