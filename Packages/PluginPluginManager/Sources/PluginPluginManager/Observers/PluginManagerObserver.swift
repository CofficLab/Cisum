import Foundation
import ProviderPluginManaging
import MagicKit

/// 插件启停变化的集中观察者（迁移 Phase 4）。
///
/// 订阅 `PluginManaging` Provider 的 `enabledStateChanged` 语义事件，驱动
/// `PluginManagementViewModel.incrementRevision()`；取代原 `PluginManagementView`
/// 对 `PluginManaging` 语义事件的直接订阅。
@MainActor
final class PluginManagerObserver: SuperLog {
    nonisolated static let emoji = "🧩"
    nonisolated static let verbose = false

    private weak var viewModel: PluginManagementViewModel?
    private var handle: (any PluginManagingObserverHandle)?

    init(manager: any PluginManaging, viewModel: PluginManagementViewModel) {
        self.viewModel = viewModel
        handle = manager.addPluginObserver { [weak self] _ in
            self?.viewModel?.incrementRevision()
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
