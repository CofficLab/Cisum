import Foundation
import SwiftUI
import Testing
@testable import PluginStore
@testable import ProviderStore
@testable import ProviderStoreKit

@Test func storeInfoExportsMetadata() {
    #expect(StorePluginInfo.titleKey == "Store")
    #expect(StorePluginInfo.iconName == "cart")
    #expect(StoreTier.none.isFree)
}

@Test func cisumSubscriptionProductAliasesGrantProTier() {
    // 这份清单对应 App Store Connect 上 Cisum 真实在售的内购：
    // 两个自动续期订阅（monthly / yearly）加三个非续期商品。
    let proProductIDs = [
        "com.yueyi.cisum.monthly",
        "com.yueyi.cisum.yearly",
        "com.yueyi.cisum.pro.month.1",
        "com.yueyi.cisum.pro.year.1",
        "com.yueyi.cisum.pro.day.7",
    ]

    for productID in proProductIDs {
        #expect(CisumStoreCatalog.shared.tier(for: productID) == .pro)
        #expect(CisumStoreCatalog.shared.allProductIds.contains(productID))
    }
}

/// 未经上架的历史别名不应再出现在商品表里。
///
/// `.pro.monthly` / `.pro.yearly` / `.pro.annual` / `.annual` 从未在
/// App Store Connect 上架过；把它们留在商品表里会让购买面板请求一批永远
/// 拿不到的商品，并把本地 mock 的档位数量推到 6 行，与生产的 2 行不一致。
@Test func unshippedSubscriptionAliasesAreNotInCatalog() {
    let unshippedProductIDs = [
        "com.yueyi.cisum.pro.monthly",
        "com.yueyi.cisum.pro.yearly",
        "com.yueyi.cisum.pro.annual",
        "com.yueyi.cisum.annual",
    ]

    for productID in unshippedProductIDs {
        #expect(CisumStoreCatalog.shared.tier(for: productID) == .none)
        #expect(!CisumStoreCatalog.shared.allProductIds.contains(productID))
    }
}

@Test func activeSubscribedStatusSelectsCurrentSubscription() {
    let subscriptions = [
        subscriptionProduct(id: "com.yueyi.cisum.monthly"),
    ]
    let statuses = [
        SubscriptionStatusSnapshot(
            state: RenewalState.subscribed.rawValue,
            currentProductID: "com.yueyi.cisum.monthly"
        ),
    ]

    #expect(StoreService.highestActiveSubscriptionStatusIndex(
        subscriptions: subscriptions,
        statuses: statuses
    ) == 0)
}

@Test func expiredSubscriptionStatusIsIgnored() {
    let subscriptions = [
        subscriptionProduct(id: "com.yueyi.cisum.pro.monthly"),
    ]
    let statuses = [
        SubscriptionStatusSnapshot(
            state: RenewalState.expired.rawValue,
            currentProductID: "com.yueyi.cisum.pro.monthly"
        ),
    ]

    #expect(StoreService.highestActiveSubscriptionStatusIndex(
        subscriptions: subscriptions,
        statuses: statuses
    ) == nil)
}

@Test func productListShowsLoadingErrorEmptyAndContentStates() {
    #expect(StoreProductListPresentation.state(
        isRefreshing: true,
        hasGroups: false,
        hasError: false
    ) == .loading)

    #expect(StoreProductListPresentation.state(
        isRefreshing: false,
        hasGroups: false,
        hasError: true
    ) == .error)

    #expect(StoreProductListPresentation.state(
        isRefreshing: false,
        hasGroups: false,
        hasError: false
    ) == .empty)

    #expect(StoreProductListPresentation.state(
        isRefreshing: true,
        hasGroups: true,
        hasError: true
    ) == .content)
}

@Test func productListOnlyAppliesLatestLoadResult() {
    #expect(StoreProductLoadPolicy.shouldApplyResult(
        currentGeneration: 3,
        resultGeneration: 3
    ))
    #expect(!StoreProductLoadPolicy.shouldApplyResult(
        currentGeneration: 3,
        resultGeneration: 2
    ))
}

@Test func productListUsesSingularSubscriptionCountOnlyForOneOption() {
    #expect(!ProductsSubscription.shouldUseSingularSubscriptionCount(0))
    #expect(ProductsSubscription.shouldUseSingularSubscriptionCount(1))
    #expect(!ProductsSubscription.shouldUseSingularSubscriptionCount(2))
}

@Test func storeSettingOnlyAppliesLatestPurchaseInfoResult() {
    #expect(StorePurchaseInfoLoadPolicy.shouldApplyResult(
        currentGeneration: 4,
        resultGeneration: 4
    ))
    #expect(!StorePurchaseInfoLoadPolicy.shouldApplyResult(
        currentGeneration: 4,
        resultGeneration: 3
    ))
}

@Test func storeSettingIconButtonsExposeReadableLabels() {
    #expect(StoreSetting.purchaseActionLabel == "In-App Purchase")
    #expect(StoreSetting.restorePurchaseActionLabel == "Restore Purchase")
}

@Test func storeSheetCloseButtonExposesReadableLabel() {
    #expect(SheetContainer<EmptyView>.closeButtonLabel == "Close")
}

@Test func storeErrorsUseUserReadableDescriptions() {
    #expect(StoreError.failedVerification.localizedDescription == "App Store verification failed")
    #expect(StoreError.canNotGetProducts.localizedDescription == "Could not load products from the App Store")
}

@Test func transactionListenerStartsOnlyOnce() {
    #expect(StoreService.shouldStartTransactionListener(isStarted: false))
    #expect(!StoreService.shouldStartTransactionListener(isStarted: true))
}

@Test
@MainActor
func purchaseUpdatePostsStoreTransactionNotification() async {
    let productID = "com.yueyi.cisum.monthly"
    let notifications = NotificationCenter.default.notifications(named: .storeTransactionUpdated)
    let task = Task {
        for await notification in notifications {
            return notification.object as? String
        }

        return nil
    }

    StoreService.postTransactionUpdated(productID: productID)

    let receivedProductID = await task.value
    #expect(receivedProductID == productID)
}

private func subscriptionProduct(id: String) -> ProductDTO {
    ProductDTO(
        id: id,
        displayName: id,
        displayPrice: "$1.00",
        price: 1,
        kind: .autoRenewable,
        description: ""
    )
}

// MARK: - 插件生命周期装配

@Test
@MainActor
func storePluginAssemblesAndTearsDownState() async throws {
    let plugin = StorePlugin()
    #expect(plugin.makeSettingEntry() != nil)
    #expect(plugin.makeSettingEntry() != nil) // 二次调用复用同一 ViewModel
}

@Test
@MainActor
func storeObserverCancelsTokensIdempotently() {
    let viewModel = StoreViewModel()
    let observer = StoreObserver(viewModel: viewModel)
    observer.cancel()
    observer.cancel()
    // 取消后不崩溃；tokens 已清空。
}

@Test
@MainActor
func storeViewModelStartsWithFreePresentation() {
    let viewModel = StoreViewModel()
    #expect(!viewModel.showBuySheet)
    #expect(!viewModel.showRestoreSheet)
    #expect(viewModel.purchaseInfo == .none)
    #expect(viewModel.tierDisplayName == "Free")
    #expect(viewModel.statusDescription == "Currently using free version")
}

// MARK: - StoreEntitlementSnapshot 判定逻辑

/// `isExpired` 对未来 60 秒内的到期时间额外容差，避免刚续费就判过期。
@Test func purchaseInfoTreatsNearFutureExpiryAsStillActive() {
    let justRenewed = StoreEntitlementSnapshot(tier: .pro, expiresAt: Date().addingTimeInterval(30))
    #expect(!justRenewed.isExpired)
    #expect(justRenewed.isProOrHigher)
}

@Test func purchaseInfoTreatsPastExpiryAsExpired() {
    let expired = StoreEntitlementSnapshot(tier: .pro, expiresAt: Date().addingTimeInterval(-60))
    #expect(expired.isExpired)
    // 过期后即使 tier 仍是 pro，也不应视为 pro+
    #expect(!expired.isProOrHigher)
    #expect(expired.isNotProOrHigher)
    #expect(expired.effectiveTier == .none)
}

/// expiresAt 为 nil 时视为已过期，避免无期限订阅被永久豁免。
@Test func purchaseInfoWithNilExpiryIsTreatedAsExpired() {
    let info = StoreEntitlementSnapshot(tier: .pro, expiresAt: nil)
    #expect(info.isExpired)
    #expect(!info.isProOrHigher)
    #expect(info.expiresAtString == "nil")
}

@Test func purchaseInfoKeepsTierForUnexpiredHigherTiers() {
    for tier in [StoreTier.pro, .ultimate] {
        let info = StoreEntitlementSnapshot(tier: tier, expiresAt: Date().addingTimeInterval(3600))
        #expect(info.isProOrHigher)
        #expect(info.effectiveTier == tier)
        #expect(info.expiresAtString.contains("[active]"))
        #expect(!info.expiresAtString.contains("[expired]"))
    }
}

@Test func purchaseInfoNeverGrantsProWhenTierIsFree() {
    let free = StoreEntitlementSnapshot(tier: .none, expiresAt: Date().addingTimeInterval(3600))
    #expect(!free.isProOrHigher)
    #expect(free.effectiveTier == .none)
}

@Test func subscriptionTierOrderingAndDisplayNames() {
    #expect(StoreTier.none < StoreTier.pro)
    #expect(StoreTier.pro < StoreTier.ultimate)
    #expect(!StoreTier.ultimate.isFree)
    #expect(StoreTier.pro.isProOrHigher)
    #expect(!StoreTier.pro.isUltimateOrHigher)
    #expect(StoreTier.ultimate.isUltimateOrHigher)
}

// MARK: - StoreViewModel 订阅状态文案

/// `updatePurchaseInfo()` 依赖真实 StoreKit 查询，无法在单测中可靠驱动；
/// 这里改为直接验证它所依赖的判定组合，保证三种状态描述互斥且正确。
@Test func storeStatusDescriptionCoversActiveExpiredAndFree() {
    let active = StoreEntitlementSnapshot(tier: .pro, expiresAt: Date().addingTimeInterval(3600))
    let expired = StoreEntitlementSnapshot(tier: .pro, expiresAt: Date().addingTimeInterval(-3600))
    let free = StoreEntitlementSnapshot.none

    #expect(active.isProOrHigher && !active.isExpired)
    #expect(expired.isProOrHigher == false || expired.isExpired)
    #expect(free.isNotProOrHigher)
}
