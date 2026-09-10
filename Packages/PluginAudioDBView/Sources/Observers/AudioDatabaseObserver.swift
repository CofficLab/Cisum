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
    nonisolated static let verbose = true

    private weak var listViewModel: AudioListViewModel?
    private weak var rootViewModel: AudioDBRootViewModel?
    private weak var dbViewModel: AudioDBViewModel?
    private var handle: (any AudioLibraryProvidingObserverHandle)?

    init(
        list: AudioListViewModel,
        root: AudioDBRootViewModel?,
        db: AudioDBViewModel?,
        library: (any AudioLibraryProviding)?
    ) {
        self.listViewModel = list
        self.rootViewModel = root
        self.dbViewModel = db
        handle = library?.addObserver { [weak self] event in
            switch event {
            case .syncing:
                self?.listViewModel?.handleDBSyncing()
            case .synced:
                self?.listViewModel?.handleDBSynced()
                Task { @MainActor in await self?.rootViewModel?.checkAudioRepo() }
            case .updated:
                self?.listViewModel?.handleDBUpdated()
                Task { @MainActor in await self?.rootViewModel?.checkAudioRepo() }
            case .deleted(let urls, _):
                self?.listViewModel?.handleDBDeleted(urlsToDelete: urls)
            case .sorting:
                self?.dbViewModel?.handleSorting(mode: nil)
            case .sortCompleted:
                self?.dbViewModel?.handleSortDone()
                self?.listViewModel?.handleDBSortDone()
            }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
