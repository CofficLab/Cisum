import Foundation
import StoreKit
import SwiftUI
import Testing
@testable import ProviderStore

@Suite(.serialized)
struct ProviderStoreTests {
    @Test
    func purchaseInfoResolvesEntitlementAndExpiry() {
        let active = PurchaseInfo(tier: .pro, expiresAt: .now.addingTimeInterval(3_600))
        let expired = PurchaseInfo(tier: .ultimate, expiresAt: .now.addingTimeInterval(-120))
        let freeWithFutureExpiry = PurchaseInfo(tier: .none, expiresAt: .now.addingTimeInterval(3_600))

        #expect(active.isProOrHigher)
        #expect(!active.isNotProOrHigher)
        #expect(active.effectiveTier == .pro)
        #expect(!active.isExpired)
        #expect(active.expiresAtString.hasSuffix("[active]"))

        #expect(expired.isExpired)
        #expect(!expired.isProOrHigher)
        #expect(expired.isNotProOrHigher)
        #expect(expired.effectiveTier == .none)
        #expect(expired.expiresAtString.hasSuffix("[expired]"))

        #expect(freeWithFutureExpiry.isNotProOrHigher)
        #expect(freeWithFutureExpiry.effectiveTier == .none)
        #expect(PurchaseInfo.none.isExpired)
        #expect(PurchaseInfo.none.expiresAtString == "nil")
        #expect(PurchaseInfo.none.effectiveTier == .none)
    }

    @Test
    func subscriptionTierOrderingDisplayAndCodableAreStable() throws {
        #expect(SubscriptionTier.none < .pro)
        #expect(SubscriptionTier.pro < .ultimate)
        #expect(SubscriptionTier.none.isFreeVersion)
        #expect(!SubscriptionTier.pro.isFreeVersion)
        #expect(!SubscriptionTier.pro.isUltimateOrHigher)
        #expect(SubscriptionTier.ultimate.isProOrHigher)
        #expect(SubscriptionTier.ultimate.isUltimateOrHigher)
        #expect(SubscriptionTier.none.displayName == "Free version")
        #expect(SubscriptionTier.pro.displayName == "Pro version")
        #expect(SubscriptionTier.ultimate.displayName == "Ultimate version")

        for tier in [SubscriptionTier.none, .pro, .ultimate] {
            let data = try JSONEncoder().encode(tier)
            #expect(try JSONDecoder().decode(SubscriptionTier.self, from: data) == tier)
        }
    }

    @Test
    func productConfigurationContainsMappedProductIDs() {
        let expectedIDs: Set<String> = [
            "consumable.fuel.octane87",
            "consumable.fuel.octane89",
            "consumable.fuel.octane91",
            "nonconsumable.car",
            "nonconsumable.utilityvehicle",
            "nonconsumable.racecar",
            "com.yueyi.cisum.pro.monthly",
            "com.yueyi.cisum.monthly",
            "com.yueyi.cisum.pro.yearly",
            "com.yueyi.cisum.yearly",
            "com.yueyi.cisum.pro.annual",
            "com.yueyi.cisum.annual",
            "com.yueyi.cisum.pro.month.1",
            "com.yueyi.cisum.pro.year.1",
            "com.yueyi.cisum.pro.day.7",
            "com.yueyi.kuaiyizhi.pro.month.1",
            "com.yueyi.kuaiyizhi.pro.year.1",
            "com.yueyi.kuaiyizhi.pro.day.7",
        ]

        #expect(Set(StoreConfig.allProductIds) == expectedIDs)
        #expect(StoreConfig.tier(for: "com.yueyi.cisum.pro.monthly") == .pro)
        #expect(StoreConfig.tier(for: "consumable.fuel.octane87") == .none)
        #expect(StoreConfig.tier(for: "unknown.product") == .none)
        #expect(StoreService.tier(for: "com.yueyi.cisum.annual") == .pro)
        #expect(StoreService.tier(for: "unknown.product") == .none)
    }

    @Test
    func productGroupsFlattenSubscriptionsAndFindGroups() {
        let monthly = product(id: "monthly", price: 3)
        let yearly = product(id: "yearly", price: 20)
        let group = SubscriptionGroupDTO(name: "Pro", id: "pro", subscriptions: [monthly, yearly])
        let groups = ProductGroupsDTO(
            cars: [],
            subscriptionGroups: [group],
            nonRenewables: [],
            fuel: []
        )

        #expect(groups.subscriptions.map(\.id) == ["monthly", "yearly"])
        #expect(groups.subscriptionGroup(withId: "pro")?.name == "Pro")
        #expect(groups.subscriptionGroup(withId: "missing") == nil)
        #expect(ProductGroupsDTO(cars: [], subscriptionGroups: [], nonRenewables: [], fuel: []).subscriptions.isEmpty)
    }

    @Test
    func classifiedProductsAreSeparatedIntoStoreCategories() {
        let car = product(id: "car", price: 0)
        let subscription = product(id: "subscription", price: 5, groupID: "pro", groupName: "Pro")
        let nonRenewable = product(id: "non-renewable", price: 2)
        let fuel = product(id: "fuel", price: 1)
        let ignored = product(id: "unknown", price: 7)

        let groups = ProductGroupsDTO(classifiedProducts: [
            (.nonConsumable, car),
            (.autoRenewable, subscription),
            (.nonRenewable, nonRenewable),
            (.consumable, fuel),
            (.unknown, ignored),
        ])

        #expect(groups.cars.map(\.id) == ["car"])
        #expect(groups.subscriptions.map(\.id) == ["subscription"])
        #expect(groups.nonRenewables.map(\.id) == ["non-renewable"])
        #expect(groups.fuel.map(\.id) == ["fuel"])
    }

    @Test
    func subscriptionGroupingUsesGroupMetadataAndSortsPrices() {
        let subscriptions = [
            product(id: "monthly", price: 8, groupID: "pro", groupName: "Pro"),
            product(id: "yearly", price: 30, groupID: "pro", groupName: "Pro"),
            product(id: "legacy", price: 1),
        ]

        let groups = ProductGroupsDTO.createSubscriptionGroups(from: subscriptions)
        let proGroup = groups.first { $0.id == "pro" }
        let unknownGroup = groups.first { $0.id == "unknown" }

        #expect(groups.count == 2)
        #expect(groups.map(\.id) == ["pro", "unknown"])
        #expect(proGroup?.name == "Pro")
        #expect(proGroup?.subscriptions.map(\.id) == ["monthly", "yearly"])
        #expect(unknownGroup?.name == "unknown")
        #expect(unknownGroup?.subscriptions.map(\.id) == ["legacy"])
    }

    @Test
    func subscriptionPeriodDTOEncodesStableValues() throws {
        let period = StoreSubscriptionPeriodDTO(value: 3, unit: "month")
        let decoded = try JSONDecoder().decode(StoreSubscriptionPeriodDTO.self, from: JSONEncoder().encode(period))

        #expect(decoded == period)
        #expect(Product.SubscriptionPeriod.Unit.day.description == "day")
        #expect(Product.SubscriptionPeriod.Unit.week.description == "week")
        #expect(Product.SubscriptionPeriod.Unit.month.description == "month")
        #expect(Product.SubscriptionPeriod.Unit.year.description == "year")
    }

    @Test
    func highestActiveSubscriptionSkipsExpiredRevokedAndUnknownProducts() {
        let subscriptions = [
            product(id: "com.yueyi.cisum.pro.monthly", price: 5),
            product(id: "com.yueyi.cisum.pro.yearly", price: 30),
        ]
        let statuses = [
            status(.expired, productID: "com.yueyi.cisum.pro.monthly"),
            status(.revoked, productID: "com.yueyi.cisum.pro.monthly"),
            status(.subscribed, productID: nil),
            status(.subscribed, productID: "unknown.product"),
            status(.subscribed, productID: "com.yueyi.cisum.pro.monthly"),
            status(.subscribed, productID: "com.yueyi.cisum.pro.yearly"),
        ]

        #expect(StoreService.highestActiveSubscriptionStatusIndex(
            subscriptions: subscriptions,
            statuses: statuses
        ) == 4)
        #expect(StoreService.highestActiveSubscriptionStatusIndex(subscriptions: [], statuses: []) == nil)
        #expect(StoreService.highestActiveSubscriptionStatusIndex(
            subscriptions: subscriptions,
            statuses: [status(.subscribed, productID: nil)]
        ) == nil)
    }

    @Test
    func storeStatePersistsAndClearsPurchaseInfo() {
        let defaults = UserDefaults.standard
        let purchaseKey = "store.purchase"
        let checkedKey = "store.lastCheckedAt"
        let previousPurchase = defaults.object(forKey: purchaseKey)
        let previousChecked = defaults.object(forKey: checkedKey)
        defer {
            if let previousPurchase { defaults.set(previousPurchase, forKey: purchaseKey) }
            else { defaults.removeObject(forKey: purchaseKey) }
            if let previousChecked { defaults.set(previousChecked, forKey: checkedKey) }
            else { defaults.removeObject(forKey: checkedKey) }
        }

        let purchase = PurchaseInfo(tier: .pro, expiresAt: .now.addingTimeInterval(3_600))
        StoreState.update(entitlement: purchase)
        #expect(StoreState.cachedPurchaseInfo() == purchase)
        #expect(defaults.object(forKey: checkedKey) is Double)

        StoreState.clear()
        #expect(StoreState.cachedPurchaseInfo() == .none)

        defaults.set(Data([0xFF]), forKey: purchaseKey)
        #expect(StoreState.cachedPurchaseInfo() == .none)
    }

    @Test
    func expiredNonRenewableEntitlementsDoNotGrantSubscriptionTier() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(StoreState.nonRenewableEntitlementInfo(
            productID: "com.yueyi.cisum.pro.monthly",
            expirationDate: now.addingTimeInterval(-1),
            now: now
        ) == nil)
        #expect(StoreState.nonRenewableEntitlementInfo(
            productID: "com.yueyi.cisum.pro.monthly",
            expirationDate: nil,
            now: now
        ) == nil)

        let active = StoreState.nonRenewableEntitlementInfo(
            productID: "com.yueyi.cisum.pro.monthly",
            expirationDate: now.addingTimeInterval(60),
            now: now
        )
        #expect(active?.tier == .pro)
        #expect(active?.expiresAt == now.addingTimeInterval(60))
    }

    @Test(arguments: [Product.ProductType.autoRenewable, .nonRenewable])
    func unknownProductsCannotExtendPaidEntitlements(type: Product.ProductType) {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let active = StoreState.EntitlementSnapshot(
            productID: "com.yueyi.cisum.pro.monthly", productType: .autoRenewable,
            expirationDate: now.addingTimeInterval(100))
        let unknown = StoreState.EntitlementSnapshot(
            productID: "unknown.subscription", productType: type,
            expirationDate: now.addingTimeInterval(10_000))
        for entries in [[active, unknown], [unknown, active]] {
            #expect(StoreState.detectedPurchaseInfo(from: entries, now: now)
                == PurchaseInfo(tier: .pro, expiresAt: now.addingTimeInterval(100)))
        }
        #expect(StoreState.detectedPurchaseInfo(from: [unknown], now: now) == .none)
    }

    @Test
    func entitlementCalibrationKeepsHighestTierAndLatestValidExpiration() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let detected = StoreState.detectedPurchaseInfo(from: [
            .init(
                productID: "com.yueyi.cisum.pro.monthly",
                productType: .autoRenewable,
                expirationDate: now.addingTimeInterval(100)
            ),
            .init(
                productID: "com.yueyi.cisum.pro.yearly",
                productType: .nonRenewable,
                expirationDate: now.addingTimeInterval(200)
            ),
            .init(
                productID: "com.yueyi.cisum.pro.monthly",
                productType: .nonRenewable,
                expirationDate: now.addingTimeInterval(-1)
            ),
            .init(
                productID: "com.yueyi.cisum.pro.yearly",
                productType: .nonRenewable,
                expirationDate: nil
            ),
            .init(
                productID: "com.yueyi.cisum.pro.monthly",
                productType: .consumable,
                expirationDate: now.addingTimeInterval(500)
            ),
        ], now: now)

        #expect(detected.tier == .pro)
        #expect(detected.expiresAt == now.addingTimeInterval(200))
        #expect(StoreState.detectedPurchaseInfo(from: [], now: now) == .none)
    }

    @Test
    func storeServiceHelpersHandleVerificationAndExpirationFallback() throws {
        #expect(try StoreService.checkVerified(VerificationResult<String>.verified("safe")) == "safe")
        #expect(StoreService.computeExpirationDate(from: nil) == .distantPast)
        #expect(StoreService.shouldStartTransactionListener(isStarted: false))
        #expect(!StoreService.shouldStartTransactionListener(isStarted: true))

        #expect(throws: StoreError.self) {
            try StoreService.checkVerified(VerificationResult<String>.unverified(
                "unsafe",
                StoreKit.VerificationResult<String>.VerificationError.invalidSignature
            ))
        }
    }

    @Test
    func storeMetadataErrorsAndNotificationNamesRemainStable() {
        #expect(StorePluginInfo.titleKey == "Store")
        #expect(StorePluginInfo.descriptionKey == "In-App purchases and subscriptions")
        #expect(StorePluginInfo.iconName == "cart")
        #expect(StoreError.failedVerification.localizedDescription == "App Store verification failed")
        #expect(StoreError.canNotGetProducts.localizedDescription == "Could not load products from the App Store")
        #expect(Notification.Name.storeTransactionUpdated.rawValue == "store.transaction.updated")
        #expect(Notification.Name.Restored.rawValue == "store.restored")

        let restoredView = EmptyView().onRestored { _ in }
        let updatedView = EmptyView().onStoreTransactionUpdated { _ in }
        withExtendedLifetime((restoredView, updatedView)) {}
    }

    @Test
    @MainActor
    func transactionNotificationIncludesProductID() async {
        let productID = "com.yueyi.cisum.pro.monthly"
        let notifications = NotificationCenter.default.notifications(named: .storeTransactionUpdated)
        let task = Task {
            for await notification in notifications {
                return notification.object as? String
            }
            return nil
        }

        StoreService.postTransactionUpdated(productID: productID)

        #expect(await task.value == productID)
    }

    @Test
    func storeStateClearResetsToNone() {
        withPreservedPurchaseCache { _ in
            StoreState.clear()
            #expect(StoreState.cachedPurchaseInfo().tier == .none)
        }
    }

    @Test(arguments: [SubscriptionTier.none, .pro, .ultimate])
    func purchaseInfoCodablePreservesOptionalExpiration(tier: SubscriptionTier) throws {
        for expiry in [Optional<Date>.none, Optional(Date(timeIntervalSince1970: 1_800_000_000))] {
            let info = PurchaseInfo(tier: tier, expiresAt: expiry)
            #expect(try JSONDecoder().decode(PurchaseInfo.self, from: JSONEncoder().encode(info)) == info)
            if expiry == nil {
                #expect(info.effectiveTier == .none)
                #expect(info.isExpired)
            }
        }
    }

    @Test
    func nonRenewableExpirationBoundaryIsStrict() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        for delta in [-1.0, 0, 1] {
            let expiry = now.addingTimeInterval(delta)
            let info = StoreState.nonRenewableEntitlementInfo(
                productID: "com.yueyi.cisum.pro.day.7", expirationDate: expiry, now: now)
            #expect((info != nil) == (delta > 0))
            if delta > 0 { #expect(info?.expiresAt == expiry) }
        }
    }

    @Test
    func subscriptionSelectionHandlesDuplicateProductsGraceAndBillingRetry() {
        let id = "com.yueyi.cisum.pro.monthly"
        let products = [product(id: id, price: 5), product(id: id, price: 7)]
        for state in [RenewalState.inGracePeriod, .inBillingRetryPeriod, .subscribed] {
            let statuses = [status(.revoked, productID: id), status(state, productID: id),
                            status(.subscribed, productID: id)]
            #expect(StoreService.highestActiveSubscriptionStatusIndex(
                subscriptions: products, statuses: statuses) == 1)
        }
        #expect(StoreService.highestActiveSubscriptionStatusIndex(subscriptions: products,
            statuses: [status(.expired, productID: id), status(.revoked, productID: id)]) == nil)
    }

    @Test
    func cachedAccessorsReflectCurrentDataAndRejectInvalidCache() {
        withPreservedPurchaseCache { defaults in
            let active = PurchaseInfo(tier: .ultimate, expiresAt: .distantFuture)
            StoreState.update(entitlement: active)
            #expect(StoreService.cachedPurchaseInfo() == active)
            #expect(StoreService.tierCached() == .ultimate)
            #expect(StoreService.expiresAtCached() == .distantFuture)

            let expired = PurchaseInfo(tier: .pro, expiresAt: .distantPast)
            StoreState.update(entitlement: expired)
            #expect(StoreService.cachedPurchaseInfo() == expired)
            #expect(StoreService.tierCached() == .none)
            #expect(StoreService.expiresAtCached() == .distantPast)

            let invalidValues: [Any] = ["not data", Data("{}".utf8), Data("{\"tier\":999}".utf8)]
            for invalid in invalidValues {
                defaults.set(invalid, forKey: "store.purchase")
                #expect(StoreService.cachedPurchaseInfo() == .none)
                #expect(StoreService.tierCached() == .none)
                #expect(StoreService.expiresAtCached() == nil)
            }
        }
    }
}

private func withPreservedPurchaseCache(_ body: (UserDefaults) -> Void) {
    let defaults = UserDefaults.standard
    let keys = ["store.purchase", "store.lastCheckedAt"]
    let previous = keys.map { defaults.object(forKey: $0) }
    defer {
        for (key, value) in zip(keys, previous) {
            if let value { defaults.set(value, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }
    }
    body(defaults)
}

private func product(
    id: String,
    price: Decimal,
    groupID: String? = nil,
    groupName: String? = nil
) -> ProductDTO {
    let subscription = groupID.map {
        SubscriptionInfoDTO(
            subscriptionPeriod: StoreSubscriptionPeriodDTO(value: 1, unit: "month"),
            hasIntroductoryOffer: false,
            promotionalOffersCount: 0,
            introductoryOffer: nil,
            groupDisplayName: groupName ?? $0,
            groupID: $0
        )
    }
    return ProductDTO(
        id: id,
        displayName: id,
        displayPrice: "\(price)",
        price: price,
        kind: .autoRenewable,
        subscription: subscription,
        description: ""
    )
}

private func status(
    _ state: RenewalState,
    productID: String?
) -> StoreService.SubscriptionStatusSnapshot {
    StoreService.SubscriptionStatusSnapshot(state: state.rawValue, currentProductID: productID)
}

// MARK: - StoreState 纯逻辑

@Test
func entitlementDetectionMergesTiersAndMaxExpiration() {
    let now = Date()
    let snapshots = [
        StoreState.EntitlementSnapshot(
            productID: "com.yueyi.cisum.pro.monthly",
            productType: .autoRenewable,
            expirationDate: now.addingTimeInterval(7_200)
        ),
        StoreState.EntitlementSnapshot(
            productID: "consumable.fuel.octane87",
            productType: .consumable,
            expirationDate: nil
        ),
        StoreState.EntitlementSnapshot(
            productID: "nonconsumable.car",
            productType: .nonConsumable,
            expirationDate: nil
        ),
    ]

    let info = StoreState.detectedPurchaseInfo(from: snapshots, now: now)
    #expect(info.tier == .pro)
    #expect(info.expiresAt == now.addingTimeInterval(7_200))
}

@Test
func entitlementDetectionIgnoresExpiredNonRenewable() {
    let now = Date()
    let expired = StoreState.EntitlementSnapshot(
        productID: "com.yueyi.cisum.pro.month.1",
        productType: .nonRenewable,
        expirationDate: now.addingTimeInterval(-60)
    )

    let info = StoreState.detectedPurchaseInfo(from: [expired], now: now)
    #expect(info.tier == .none)
    #expect(info.expiresAt == nil)
}

@Test
func entitlementDetectionCountsActiveNonRenewable() {
    let now = Date()
    let active = StoreState.EntitlementSnapshot(
        productID: "com.yueyi.cisum.pro.day.7",
        productType: .nonRenewable,
        expirationDate: now.addingTimeInterval(86_400)
    )

    let info = StoreState.detectedPurchaseInfo(from: [active], now: now)
    #expect(info.tier == .pro)
    #expect(info.expiresAt == now.addingTimeInterval(86_400))
}

@Test
func nonRenewableEntitlementRequiresFutureExpiration() {
    let now = Date()
    #expect(StoreState.nonRenewableEntitlementInfo(
        productID: "com.yueyi.cisum.pro.month.1",
        expirationDate: now.addingTimeInterval(3_600),
        now: now
    ) != nil)
    #expect(StoreState.nonRenewableEntitlementInfo(
        productID: "com.yueyi.cisum.pro.month.1",
        expirationDate: now.addingTimeInterval(-3_600),
        now: now
    ) == nil)
    #expect(StoreState.nonRenewableEntitlementInfo(
        productID: "com.yueyi.cisum.pro.month.1",
        expirationDate: nil,
        now: now
    ) == nil)
}

// MARK: - StoreKit 校验结果解包

/// verified 结果应原样返回，不得篡改载荷。
@Test func checkVerifiedUnwrapsVerifiedPayload() throws {
    let payload = "safe-value"
    let result = VerificationResult<String>.verified(payload)
    #expect(try StoreService.checkVerified(result) == payload)
}

/// `checkVerified` 的 unverified 分支无法在单测中覆盖：
/// `VerificationResult<T>.VerificationError` 没有公开构造器，
/// 只能由 StoreKit 在真实验签失败时产生。
/// 这里改为锁定「唯一可构造的分支必须成功解包」，避免该函数被误改成静默吞错。
@Test func checkVerifiedOnlyExposesVerifiedBranchInUnitTests() throws {
    // 泛型约束：函数必须对任意可验签类型可用
    func roundTrip<T>(_ value: T) throws -> T {
        try StoreService.checkVerified(VerificationResult<T>.verified(value))
    }

    #expect(try roundTrip(42) == 42)
    #expect(try roundTrip("id") == "id")
    #expect(try roundTrip([1, 2, 3]) == [1, 2, 3])
}

@Test func storeErrorMessagesRemainUserReadable() {
    #expect(StoreError.failedVerification.errorDescription?.isEmpty == false)
    #expect(StoreError.canNotGetProducts.errorDescription?.isEmpty == false)

    // 未知商品 ID 不应被当成订阅权益
    #expect(StoreService.tier(for: "definitely.not.a.product") == .none)
}

/// 无订阅状态时应回退到 `distantPast`（即视为已过期），而不是 `now`，
/// 否则一次查询失败就会让用户被误判为付费用户。
@Test func computeExpirationDateFallsBackToDistantPastWithoutStatus() {
    let fallback = StoreService.computeExpirationDate(from: nil)
    #expect(fallback == Date.distantPast)
    #expect(fallback < Date(timeIntervalSince1970: 0))
}

@Test func storeTransactionListenerStartsOnlyOnce() {
    #expect(StoreService.shouldStartTransactionListener(isStarted: false))
    #expect(!StoreService.shouldStartTransactionListener(isStarted: true))
}
