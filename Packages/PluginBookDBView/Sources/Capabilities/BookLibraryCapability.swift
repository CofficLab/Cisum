import Foundation
import ProviderBook

/// 书库事件：只保留本插件关心的书籍语义，屏蔽内核事件的原始载荷。
@MainActor
public enum BookLibraryEvent {
    case librarySyncing
    case librarySynced
    case libraryChanged
    case libraryDeleted
    case playbackStateChanged(url: URL?)
}

/// 书库监听句柄。
@MainActor
public protocol BookLibraryObserverHandle: AnyObject {
    /// 停止接收后续书库变更通知。重复调用无副作用。
    func cancel()
}

/// 有声书库视图与设置页所需的最小书库能力。
///
/// 内核 `BookDatabaseProviding` 还包含 `savePlaybackState` /
/// `storeCurrentBookURL` / `storeCurrentBookTime` / `coverData(for:)` 等
/// 本插件不消费的写入与封面能力；本插件只做「读取书库 + 同步导入项 +
/// 读取播放进度 + 订阅变更」，故在此收窄。
///
/// 标记为 `public`：`BookDBViewDependencies` / `BookDBDependencies` 是本包的
/// 公开依赖结构，需要向宿主暴露该能力类型。
@MainActor
public protocol BookLibraryCapability: AnyObject {
    /// 书库磁盘目录；尚未配置时为 `nil`。
    var bookDisk: URL? { get }

    /// 数据库根目录。即使书库磁盘尚未配置，该目录也可用。
    var databaseRoot: URL { get }

    /// 返回当前书库中可展示的书籍 DTO。
    func books(reason: String) async -> [BookDTO]

    /// 将已复制到书库的文件/目录同步到数据库。
    func syncImportedItems(_ items: [URL]) async throws

    /// 返回书籍封面原始数据；渲染由 View 插件负责。
    func coverData(for bookURL: URL) async -> Data?

    /// 读取指定书籍的播放状态。
    func playbackState(for bookURL: URL) async -> BookPlaybackStateDTO?

    /// 读取跨设备同步的当前书籍 URL 偏好。
    func currentBookURL() -> URL?

    /// 读取跨设备同步的当前书籍播放进度偏好。
    func currentBookTime() -> TimeInterval?

    /// 订阅书库变更；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (BookLibraryEvent) -> Void
    ) -> any BookLibraryObserverHandle
}

/// 将内核 `BookDatabaseProviding` 收窄为本插件的书库能力。
@MainActor
public final class BookLibraryCapabilityAdapter: BookLibraryCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力应退化为「无书库」而非延长其生命周期。
    private weak var books: (any BookDatabaseProviding)?

    public init(books: (any BookDatabaseProviding)?) {
        self.books = books
    }

    public var bookDisk: URL? { books?.bookDisk }
    public var databaseRoot: URL { books?.databaseRoot ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true) }

    public func books(reason: String) async -> [BookDTO] {
        await books?.books(reason: reason) ?? []
    }

    public func syncImportedItems(_ items: [URL]) async throws {
        try await books?.syncImportedItems(items)
    }

    public func coverData(for bookURL: URL) async -> Data? {
        await books?.coverData(for: bookURL)
    }

    public func playbackState(for bookURL: URL) async -> BookPlaybackStateDTO? {
        await books?.playbackState(for: bookURL)
    }

    public func currentBookURL() -> URL? { books?.currentBookURL() }
    public func currentBookTime() -> TimeInterval? { books?.currentBookTime() }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (BookLibraryEvent) -> Void
    ) -> any BookLibraryObserverHandle {
        guard let books else { return BookLibraryObserverHandleBox(cancelAction: nil) }
        // 内核事件携带 totalCount / urls 等载荷，但本插件的消费者只按事件类型
        // 分派（数量与 URL 列表由 ViewModel 自行重新拉取），故在此剥离子集。
        let handle = books.addObserver { event in
            switch event {
            case .librarySyncing: callback(.librarySyncing)
            case .librarySynced: callback(.librarySynced)
            case .libraryChanged: callback(.libraryChanged)
            case .libraryDeleted: callback(.libraryDeleted)
            case .playbackStateChanged(let url): callback(.playbackStateChanged(url: url))
            case .storageLocationChanged: break
            }
        }
        return BookLibraryObserverHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `BookProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class BookLibraryObserverHandleBox: BookLibraryObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}