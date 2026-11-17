import Foundation
import ProviderBook

/// 书籍封面区的书库事件。
@MainActor
enum BookHeroLibraryEvent {
    /// 书籍列表、封面或书库位置发生变化。
    case changed
}

/// 书籍封面区监听句柄。
@MainActor
protocol BookHeroLibraryObserverHandle: AnyObject {
    /// 停止接收后续事件。重复调用无副作用。
    func cancel()
}

/// 书籍封面区所需的最小书库能力。
@MainActor
protocol BookHeroLibraryCapability: AnyObject {
    /// 书库磁盘目录；尚未配置时为 `nil`。
    var bookDisk: URL? { get }

    /// 当前书库中的书籍列表。
    func books() async -> [BookDTO]

    /// 指定书籍的封面原始数据。
    func coverData(for bookURL: URL) async -> Data?

    /// 订阅书库变化；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (BookHeroLibraryEvent) -> Void
    ) -> any BookHeroLibraryObserverHandle
}

/// 将内核 `BookDatabaseProviding` 收窄为书籍封面区的书库能力。
@MainActor
final class BookHeroLibraryCapabilityAdapter: BookHeroLibraryCapability {
    /// `weak` 持有 Provider：Provider 可能已被 unregister，此时退化为「无书库」。
    private weak var books: (any BookDatabaseProviding)?

    init(books: (any BookDatabaseProviding)?) {
        self.books = books
    }

    var bookDisk: URL? { books?.bookDisk }

    func books() async -> [BookDTO] {
        await books?.books(reason: "BookHero") ?? []
    }

    func coverData(for bookURL: URL) async -> Data? {
        await books?.coverData(for: bookURL)
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (BookHeroLibraryEvent) -> Void
    ) -> any BookHeroLibraryObserverHandle {
        guard let books else { return BookHeroLibraryHandleBox(cancelAction: nil) }
        let handle = books.addObserver { event in
            switch event {
            case .librarySynced, .libraryChanged, .libraryDeleted, .storageLocationChanged:
                callback(.changed)
            default:
                break
            }
        }
        return BookHeroLibraryHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核句柄适配为本插件句柄类型，避免 Provider 句柄类型泄漏到能力协议之外。
@MainActor
private final class BookHeroLibraryHandleBox: BookHeroLibraryObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}
