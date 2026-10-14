import Foundation
import ProviderBook

/// 书籍设置关心的书库信号：存储位置变化（需刷新路径展示）。
@MainActor
enum BookSettingsLibraryEvent {
    /// 书库存储位置变化。
    case storageLocationChanged
}

/// 书库监听句柄。
@MainActor
protocol BookSettingsLibraryObserverHandle: AnyObject {
    /// 停止接收后续书库变更通知。重复调用无副作用。
    func cancel()
}

/// 书籍设置页所需的最小书库能力。
///
/// 内核 `BookProviding` 的列表、播放状态、删除等能力设置页均不消费，
/// 只订阅「存储位置变化」这一信号。
@MainActor
protocol BookSettingsLibraryCapability: AnyObject {
    /// 订阅书库存储位置变化；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (BookSettingsLibraryEvent) -> Void
    ) -> any BookSettingsLibraryObserverHandle
}

/// 将内核 `BookProviding` 收窄为书籍设置页的书库能力。
@MainActor
final class BookSettingsLibraryCapabilityAdapter: BookSettingsLibraryCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「收不到书库信号」而非延长其生命周期。
    private weak var books: (any BookProviding)?

    init(books: (any BookProviding)?) {
        self.books = books
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (BookSettingsLibraryEvent) -> Void
    ) -> any BookSettingsLibraryObserverHandle {
        guard let books else { return BookSettingsLibraryHandleBox(cancelAction: nil) }
        let handle = books.addObserver { event in
            guard case .storageLocationChanged = event else { return }
            callback(.storageLocationChanged)
        }
        return BookSettingsLibraryHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `BookProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class BookSettingsLibraryHandleBox: BookSettingsLibraryObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}