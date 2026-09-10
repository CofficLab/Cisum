import Foundation
import OSLog
import ProviderBook
import ProviderBook
import MagicKit

/// 书籍数据库事件的集中观察者（迁移 Phase 3）。
///
/// 订阅数据库同步/更新/删除/排序/播放状态通知，转发到
/// `BookGridViewModel`；取代 `BookGrid` 的 `onBookDB*` 修饰符与
/// `BookTile` 的 `.onReceive(.bookStateUpdated)` 直接订阅。
@MainActor
final class DBObserver: SuperLog {
    nonisolated static let emoji = "🗃️"
    nonisolated static let verbose = true

    private weak var viewModel: BookGridViewModel?
    private var providerHandle: (any BookProvidingObserverHandle)?

    init(viewModel: BookGridViewModel, provider: any BookDatabaseProviding) {
        self.viewModel = viewModel
        if Self.verbose { os_log("\(Self.t)👀 BookDatabaseObserver 初始化") }
        providerHandle = provider.addObserver { [weak self] event in
            Task { @MainActor in
                switch event {
                case .librarySyncing: self?.viewModel?.handleBookDBSyncing()
                case .librarySynced: self?.viewModel?.handleBookDBSynced()
                case .libraryChanged: self?.viewModel?.handleBookDBUpdated()
                case .libraryDeleted: self?.viewModel?.handleBookDBDeleted()
                case .librarySorted: self?.viewModel?.handleBookDBSortDone()
                case let .playbackStateChanged(url): self?.viewModel?.handleBookStateUpdated(url)
                case .storageLocationChanged: break
                }
            }
        }
    }

    func cancel() {
        if Self.verbose { os_log("\(Self.t)🧹 BookDatabaseObserver 取消") }
        providerHandle?.cancel()
        providerHandle = nil
    }
}
