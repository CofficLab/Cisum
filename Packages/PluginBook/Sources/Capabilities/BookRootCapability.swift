import Foundation
import ProviderBook

/// 书籍根容器所需的最小书库能力。
///
/// 内核 `BookDatabaseProviding` 的列表读取、播放状态、删除等能力根容器
/// 均不消费——根容器只负责在「数据层是否就绪」时展示加载态或错误态。
///
/// 收窄后 `BookRootViewModel` 的依赖面从 14 成员的宽接口收敛为一个布尔量，
/// 同时把「Provider 已 unregister」与「Provider 未就绪」两种退化状态
/// 统一表达为 `isAvailable == false`。
@MainActor
protocol BookRootCapability: AnyObject {
    /// 书库数据层是否就绪（磁盘与索引可访问）。
    var isAvailable: Bool { get }
}

/// 将内核 `BookDatabaseProviding` 收窄为书籍根容器的最小能力。
@MainActor
final class BookRootCapabilityAdapter: BookRootCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「数据层未就绪」而非延长其生命周期。
    private weak var books: (any BookDatabaseProviding)?

    init(books: (any BookDatabaseProviding)?) {
        self.books = books
    }

    var isAvailable: Bool { books?.isAvailable ?? false }
}