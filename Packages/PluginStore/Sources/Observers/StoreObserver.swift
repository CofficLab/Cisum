import Foundation
import MagicKit
import ProviderStore

/// 商店交易事件的集中观察者（迁移 Phase 4）。
///
/// 订阅 `.storeTransactionUpdated` 与 `.Restored` 通知，驱动
/// `StoreViewModel.updatePurchaseInfo()`；取代原 `StoreSetting`
/// 的两个 `.onReceive` 直接订阅。
@MainActor
final class StoreObserver: SuperLog {
    nonisolated static let emoji = "🛒"
    nonisolated static let verbose = false

    private weak var viewModel: StoreViewModel?
    private var tokens: [NSObjectProtocol] = []

    init(viewModel: StoreViewModel) {
        self.viewModel = viewModel

        let center = NotificationCenter.default
        tokens.append(center.addObserver(forName: .storeTransactionUpdated, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.viewModel?.updatePurchaseInfo() }
        })
        tokens.append(center.addObserver(forName: .Restored, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.viewModel?.updatePurchaseInfo() }
        })
    }

    func cancel() {
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
        tokens.removeAll()
    }
}
