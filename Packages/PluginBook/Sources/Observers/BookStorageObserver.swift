import Foundation
import OSLog
import ProviderStorage
import MagicKit

/// 书籍存储位置变化的集中观察者（迁移 Phase 3）。
///
/// 订阅 `StorageProviding` 的位置变化事件，驱动 `BookRootViewModel`
/// 重新初始化容器；取代原 `BookRootView` 的 `BookStorageChangeModifier`
/// 多通知 `.onReceive` 订阅。
@MainActor
final class BookStorageObserver: SuperLog {
    nonisolated static let emoji = "📦"
    nonisolated static let verbose = false

    private weak var viewModel: BookRootViewModel?
    private var handle: (any StorageProvidingObserverHandle)?

    init(storage: any StorageProviding, viewModel: BookRootViewModel) {
        self.viewModel = viewModel
        if Self.verbose { os_log("\(Self.t)👀 BookStorageObserver 初始化") }

        // Initial sync：先同步当前状态，再注册监听，防止丢事件。
        if storage.hasUsableStorageLocation {
            Task { @MainActor in
                viewModel.reloadContainer()
            }
        }

        handle = storage.addObserver { [weak self] event in
            Task { @MainActor in
                switch event {
                case .locationChanged, .storageAvailabilityChanged:
                    if Self.verbose { os_log("\(Self.t)🔁 收到存储事件: \(String(describing: event))") }
                    self?.viewModel?.handleStorageLocationChanged()
                }
            }
        }
    }

    func cancel() {
        if Self.verbose { os_log("\(Self.t)🧹 BookStorageObserver 取消") }
        handle?.cancel()
        handle = nil
    }
}
