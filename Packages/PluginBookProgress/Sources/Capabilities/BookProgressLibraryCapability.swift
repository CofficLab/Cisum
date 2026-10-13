import Foundation
import ProviderBook

/// 书库事件：只保留书籍进度关心的删除信号。
@MainActor
enum BookProgressLibraryEvent {
    /// 书籍被删除。
    case libraryDeleted([URL])
}

/// 书库监听句柄。
@MainActor
protocol BookProgressLibraryObserverHandle: AnyObject {
    /// 停止接收后续书库变更通知。重复调用无副作用。
    func cancel()
}

/// 书籍进度所需的最小书库能力。
///
/// 内核 `BookDatabaseProviding` 的读列表、同步导入、封面、排序等能力本插件
/// 均不消费，只保留「当前书籍进度的读写 + 磁盘目录 + 删除事件」。
///
/// 收窄的实际收益：入口原先注入 6 个各自闭包（读 URL、读时间、写 URL、
/// 写时间、取磁盘、保存状态），每个都在内部解析同一个 `bookProvider`；
/// 收敛到本能力后，ViewModel 只面对一个明确的依赖，解析与降级语义
/// 由 Adapter 统一承担。
@MainActor
protocol BookProgressLibraryCapability: AnyObject {
    /// 书库磁盘目录；尚未配置时为 `nil`。
    var bookDisk: URL? { get }

    /// 读取跨设备同步的当前书籍 URL 偏好。
    func currentBookURL() -> URL?

    /// 读取跨设备同步的当前书籍播放进度偏好。
    func currentBookTime() -> TimeInterval?

    /// 写入当前书籍 URL 偏好（`nil` 清除）。
    func storeCurrentBookURL(_ url: URL?)

    /// 写入当前书籍播放进度。
    func storeCurrentBookTime(_ time: TimeInterval)

    /// 保存指定书籍的播放状态。
    func savePlaybackState(for bookURL: URL, currentURL: URL?, time: TimeInterval?) async throws

    /// 订阅书库删除事件；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (BookProgressLibraryEvent) -> Void
    ) -> any BookProgressLibraryObserverHandle
}

/// 将内核 `BookDatabaseProviding` 收窄为书籍进度的书库能力。
@MainActor
final class BookProgressLibraryCapabilityAdapter: BookProgressLibraryCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「无书库」而非延长其生命周期。
    private weak var books: (any BookDatabaseProviding)?

    init(books: (any BookDatabaseProviding)?) {
        self.books = books
    }

    var bookDisk: URL? { books?.bookDisk }

    func currentBookURL() -> URL? { books?.currentBookURL() }
    func currentBookTime() -> TimeInterval? { books?.currentBookTime() }
    func storeCurrentBookURL(_ url: URL?) { books?.storeCurrentBookURL(url) }
    func storeCurrentBookTime(_ time: TimeInterval) { books?.storeCurrentBookTime(time) }

    func savePlaybackState(for bookURL: URL, currentURL: URL?, time: TimeInterval?) async throws {
        try await books?.savePlaybackState(for: bookURL, currentURL: currentURL, time: time)
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (BookProgressLibraryEvent) -> Void
    ) -> any BookProgressLibraryObserverHandle {
        guard let books else { return BookProgressLibraryHandleBox(cancelAction: nil) }
        let handle = books.addObserver { event in
            guard case let .libraryDeleted(urls) = event else { return }
            callback(.libraryDeleted(urls))
        }
        return BookProgressLibraryHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `BookProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class BookProgressLibraryHandleBox: BookProgressLibraryObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}