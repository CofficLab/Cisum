import MagicKit
import os

/// 书库事件观察者：把书库变更信号转发到有声书控制 ViewModel。
///
/// 取代原插件入口中内联的 `bookProviderObserver` 原始句柄：入口不再
/// 直接触碰 `BookProvidingObserverHandle`，订阅与取消统一在观察者内。
@MainActor
final class BookControlLibraryObserver: SuperLog {
    nonisolated static let emoji = "📚"
    nonisolated static let verbose = false

    private weak var viewModel: BookControlViewModel?
    private var handle: (any BookControlLibraryObserverHandle)?

    init(library: any BookControlLibraryCapability, viewModel: BookControlViewModel) {
        self.viewModel = viewModel
        handle = library.addObserver { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                switch event {
                case .libraryChanged:
                    self.viewModel?.handleBookDBRefreshed()
                case .libraryDeleted(let urls):
                    self.viewModel?.handleBookDBDeleted(deletedURLs: urls)
                case .storageLocationReset:
                    self.viewModel?.handleStorageLocationDidReset()
                }
            }
        }
    }

    func cancel() {
        if Self.verbose { os_log("\(Self.t)🧹 BookControlLibraryObserver 取消") }
        handle?.cancel()
        handle = nil
    }
}