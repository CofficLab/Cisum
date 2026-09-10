import Foundation
import ProviderAudioLibrary
import MagicKit

/// 音频数据库事件的集中观察者（迁移 Phase 2）。
///
/// 订阅数据库同步/更新/删除/排序通知，转发到 `AudioListViewModel`、
/// `AudioDBRootViewModel` 与 `AudioDBViewModel`；取代各 View 直接
/// `.onReceive(NotificationCenter...)` 的订阅。
@MainActor
final class AudioDatabaseObserver: SuperLog {
    nonisolated static let emoji = "🗃️"
    nonisolated static let verbose = false

    private weak var listViewModel: AudioListViewModel?
    private weak var rootViewModel: AudioDBRootViewModel?
    private weak var dbViewModel: AudioDBViewModel?
    private var tokens: [NSObjectProtocol] = []

    init(
        list: AudioListViewModel,
        root: AudioDBRootViewModel?,
        db: AudioDBViewModel?
    ) {
        self.listViewModel = list
        self.rootViewModel = root
        self.dbViewModel = db

        let center = NotificationCenter.default
        tokens.append(center.addObserver(forName: .dbSynced, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.listViewModel?.handleDBSynced()
                await self?.rootViewModel?.checkAudioRepo()
            }
        })
        tokens.append(center.addObserver(forName: .dbSyncing, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.listViewModel?.handleDBSyncing()
            }
        })
        tokens.append(center.addObserver(forName: .dbUpdated, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.listViewModel?.handleDBUpdated()
                await self?.rootViewModel?.checkAudioRepo()
            }
        })
        tokens.append(center.addObserver(forName: .dbDeleted, object: nil, queue: .main) { [weak self] notification in
            let urls = notification.userInfo?["urls"] as? [URL] ?? []
            Task { @MainActor in
                self?.listViewModel?.handleDBDeleted(urlsToDelete: urls)
            }
        })
        tokens.append(center.addObserver(forName: .DBSorting, object: nil, queue: .main) { [weak self] notification in
            let mode = notification.userInfo?["mode"] as? String
            Task { @MainActor in
                self?.dbViewModel?.handleSorting(mode: mode)
            }
        })
        tokens.append(center.addObserver(forName: .DBSortDone, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.dbViewModel?.handleSortDone()
                self?.listViewModel?.handleDBSortDone()
            }
        })
    }

    func cancel() {
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
        tokens.removeAll()
    }
}
