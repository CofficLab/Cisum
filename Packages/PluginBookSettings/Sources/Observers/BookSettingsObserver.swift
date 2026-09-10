import Foundation
import OSLog
import ProviderBook
import MagicKit

/// 书籍设置的存储位置变化观察者（迁移 Phase 5）。
///
/// 订阅书籍 Provider 的存储位置事件，转发到 `BookSettingsViewModel`；取代原
/// `BookSettingsStorageChangeModifier` 的多通知 `.onReceive`。
@MainActor
final class BookSettingsObserver: SuperLog {
    nonisolated static let emoji = "🔧"
    nonisolated static let verbose = false

    private weak var viewModel: BookSettingsViewModel?
    private var providerHandle: (any BookProvidingObserverHandle)?

    init(viewModel: BookSettingsViewModel, provider: any BookProviding) {
        self.viewModel = viewModel
        if Self.verbose { os_log("\(Self.t)👀 BookSettingsObserver 初始化") }
        providerHandle = provider.addObserver { [weak self] event in
            guard case .storageLocationChanged = event else { return }
            Task { @MainActor [weak self] in
                self?.viewModel?.handleStorageLocationChanged()
            }
        }
    }

    func cancel() {
        if Self.verbose { os_log("\(Self.t)🧹 BookSettingsObserver 取消") }
        providerHandle?.cancel()
        providerHandle = nil
    }
}
