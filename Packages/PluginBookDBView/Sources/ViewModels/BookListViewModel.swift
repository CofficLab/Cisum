import Combine
import Foundation
import OSLog
import ProviderBook
import ProviderBook
import SwiftUI
import MagicKit

/// 书籍库列表的轻量加载容器（设置页专用）。
///
/// 与主窗口内容区（`BookGrid` / `BookGridViewModel`）相互独立：设置页
/// onAppear 触发的重载不会传播到主窗口内容区，避免其闪动。仅负责加载
/// 书籍列表与总数，不处理播放/选中态。
@MainActor
final class BookListViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = true

    @Published private(set) var books: [BookDTO] = []
    @Published private(set) var isLoading = false
    @Published private(set) var totalCount = 0

    private let bookProvider: (any BookDatabaseProviding)?
    private let reasonTag: String
    private var loadGeneration = 0

    init(
        bookProvider: (any BookDatabaseProviding)?,
        reasonTag: String = "BookListViewModel"
    ) {
        self.bookProvider = bookProvider
        self.reasonTag = reasonTag
    }

    // MARK: - View lifecycle

    /// 视图出现：加载书籍列表。
    func handleOnAppear() {
        if Self.verbose { os_log("\(Self.t)📺 设置页加载书籍列表") }
        load()
    }

    // MARK: - Loading

    private func load() {
        guard !isLoading else { return }

        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true

        Task { @MainActor in
            guard let bookProvider else {
                isLoading = false
                return
            }

            let books = await bookProvider.books(reason: reasonTag)
            guard generation == loadGeneration else { return }
            self.books = books
            self.totalCount = books.count
            self.isLoading = false
            if Self.verbose { os_log("\(Self.t)✅ 已加载 \(books.count) 本书") }
        }
    }
}
