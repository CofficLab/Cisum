import Foundation
import ProviderBook

/// 横幅解析书名所用的最小书籍库能力。
@MainActor
protocol BookLoadingLibraryCapability: AnyObject {
    /// 书库磁盘根目录；用于识别「单文件书」而不是一个章节。
    var libraryDisk: URL? { get }
    /// 有声书支持的扩展名；章节位置统计与书卡口径保持一致。
    var playableExtensions: Set<String> { get }
    /// 顶层书籍条目；不可用时返回空数组，横幅退回文件名。
    func books() async -> [BookLoadingBookRef]
}

/// 把内核 `BookDatabaseProviding` 收窄为横幅需要的能力。
///
/// 持有惰性解析闭包而不是 Provider 快照：数据层插件的 boot 顺序不固定，
/// 快照会让能力在 Provider 稍后就绪时永久失效。
@MainActor
final class BookLoadingLibraryCapabilityAdapter: BookLoadingLibraryCapability {
    private let resolve: @MainActor @Sendable () -> (any BookDatabaseProviding)?

    init(resolve: @escaping @MainActor @Sendable () -> (any BookDatabaseProviding)?) {
        self.resolve = resolve
    }

    var libraryDisk: URL? {
        resolve()?.bookDisk
    }

    var playableExtensions: Set<String> {
        Set(BookPluginInfo.supportedExtensions)
    }

    func books() async -> [BookLoadingBookRef] {
        guard let provider = resolve() else { return [] }
        return await provider.books(reason: "BookLoading.banner").map {
            BookLoadingBookRef(
                url: $0.url,
                title: $0.bookTitle,
                childCount: $0.childCount,
                isCollection: $0.isCollection
            )
        }
    }
}