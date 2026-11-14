import OSLog
import MagicKit

/// 书籍数据库事件的集中观察者（迁移 Phase 3）。
///
/// 订阅数据库同步/更新/删除/播放状态事件，转发到
/// `BookGridViewModel`；避免 View 直接订阅持久化层事件。
@MainActor
final class DBObserver: SuperLog {
    nonisolated static let emoji = "🗃️"
    nonisolated static let verbose = false

    private weak var viewModel: BookGridViewModel?
    private var handle: (any BookLibraryObserverHandle)?

    init(viewModel: BookGridViewModel, library: any BookLibraryCapability) {
        self.viewModel = viewModel
        if Self.verbose { os_log("\(Self.t)👀 BookDatabaseObserver 初始化") }
        handle = library.addObserver { [weak self] event in
            switch event {
            case .librarySyncing: self?.viewModel?.handleBookDBSyncing()
            case .librarySynced: self?.viewModel?.handleBookDBSynced()
            case .libraryChanged: self?.viewModel?.handleBookDBUpdated()
            case .libraryDeleted: self?.viewModel?.handleBookDBDeleted()
            case .playbackStateChanged(let url): self?.viewModel?.handleBookStateUpdated(url)
            }
        }
    }

    func cancel() {
        if Self.verbose { os_log("\(Self.t)🧹 BookDatabaseObserver 取消") }
        handle?.cancel()
        handle = nil
    }
}