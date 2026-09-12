import Foundation
import StoreKit
import SwiftUI
import Testing
@testable import ProviderStore

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
