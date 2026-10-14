import Foundation
import ProviderBook

/// 有声书库事件：只保留控制按钮关心的三种信号。
@MainActor
enum BookControlLibraryEvent {
    /// 书库内容变化（需要刷新可播放章节缓存）。
    case libraryChanged
    /// 书籍被删除。
    case libraryDeleted([URL])
    /// 存储位置重置。
    case storageLocationReset
}

/// 书库监听句柄。
@MainActor
protocol BookControlLibraryObserverHandle: AnyObject {
    /// 停止接收后续书库变更通知。重复调用无副作用。
    func cancel()
}

/// 有声书控制按钮所需的最小书库能力。
///
/// 内核 `BookDatabaseProviding` 的列表读取、播放状态读写等能力本插件不消费；
/// 控制按钮只关心「磁盘目录（用于章节查找）+ 三种环境信号」。
@MainActor
protocol BookControlLibraryCapability: AnyObject {
    /// 书库磁盘目录；尚未配置时为 `nil`。
    var bookDisk: URL? { get }

    /// 订阅书库变更信号；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (BookControlLibraryEvent) -> Void
    ) -> any BookControlLibraryObserverHandle
}

/// 将内核 `BookDatabaseProviding` 收窄为有声书控制按钮的书库能力。
@MainActor
final class BookControlLibraryCapabilityAdapter: BookControlLibraryCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「无书库」而非延长其生命周期。
    private weak var books: (any BookDatabaseProviding)?

    init(books: (any BookDatabaseProviding)?) {
        self.books = books
    }

    var bookDisk: URL? { books?.bookDisk }

    @discardableResult
    func addObserver(
        _ callback: @escaping (BookControlLibraryEvent) -> Void
    ) -> any BookControlLibraryObserverHandle {
        guard let books else { return BookControlLibraryHandleBox(cancelAction: nil) }
        let handle = books.addObserver { event in
            switch event {
            case .libraryChanged: callback(.libraryChanged)
            case .libraryDeleted(let urls): callback(.libraryDeleted(urls))
            case .storageLocationChanged: callback(.storageLocationReset)
            case .librarySyncing, .librarySynced, .playbackStateChanged: break
            }
        }
        return BookControlLibraryHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `BookProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class BookControlLibraryHandleBox: BookControlLibraryObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}