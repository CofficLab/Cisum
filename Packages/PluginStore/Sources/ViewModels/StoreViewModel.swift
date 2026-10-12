import Combine
import Foundation
import OSLog
import MagicKit
import ProviderStore

/// 商店设置视图的状态容器（迁移 Phase 4）。
///
/// 持有订阅信息、购买/恢复弹窗状态与加载代际，统一处理
/// `updatePurchaseInfo()`；取代原 `StoreSetting` 内的全部
/// `@State` 与 `.onReceive` 订阅。
@MainActor
final class StoreViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published var showBuySheet = false
    @Published var showRestoreSheet = false
    @Published private(set) var purchaseInfo: PurchaseInfo = .none
    @Published private(set) var tierDisplayName: String = "Free"
    @Published private(set) var statusDescription: String = "Currently using free version"

    private var purchaseInfoGeneration = 0

    /// 重新加载订阅信息（原 `StoreSetting.updatePurchaseInfo()`）。
    func updatePurchaseInfo() {
        purchaseInfoGeneration += 1
        let generation = purchaseInfoGeneration

        Task {
            let info = await StoreService.getPurchaseInfo()
            await MainActor.run {
                guard StorePurchaseInfoLoadPolicy.shouldApplyResult(
                    currentGeneration: self.purchaseInfoGeneration,
                    resultGeneration: generation
                ) else { return }

                self.purchaseInfo = info
                self.tierDisplayName = StoreService.tierCached().displayName

                if info.isProOrHigher {
                    if info.isExpired {
                        self.statusDescription = String(localized: "Subscription has expired, please renew to continue using Pro features", bundle: .module)
                    } else {
                        self.statusDescription = String(localized: "Subscription is active, thank you for your support", bundle: .module)
                    }
                } else {
                    self.statusDescription = String(localized: "Currently using free version", bundle: .module)
                }
            }
        }
    }
}
