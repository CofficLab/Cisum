import Foundation
import OSLog
import MagicKit

/// 书籍存储位置变化的集中观察者（迁移 Phase 3）。
///
/// 订阅存储能力的变化信号，驱动 `BookRootViewModel` 重新初始化容器；
/// 取代原 `BookRootView` 的 `BookStorageChangeModifier` 多通知
/// `.onReceive` 订阅。
@MainActor
final class BookStorageObserver: SuperLog {
    nonisolated static let emoji = "📦"
    nonisolated static let verbose = false

    private weak var viewModel: BookRootViewModel?
    private var handle: (any BookStorageObserverHandle)?

    init(storage: any BookStorageCapability, viewModel: BookRootViewModel) {
        self.viewModel = viewModel
        if Self.verbose { os_log("\(Self.t)👀 BookStorageObserver 初始化") }

        // Initial sync：先同步当前状态，再注册监听，防止丢事件。
        if storage.hasUsableStorageLocation {
            Task { @MainActor in
                viewModel.reloadContainer()
            }
        }

        handle = storage.addObserver { [weak self] _ in
            Task { @MainActor in
                if Self.verbose { os_log("\(Self.t)🔁 收到存储变更信号") }
                self?.viewModel?.handleStorageLocationChanged()
            }
        }
    }

    func cancel() {
        if Self.verbose { os_log("\(Self.t)🧹 BookStorageObserver 取消") }
        handle?.cancel()
        handle = nil
    }
}