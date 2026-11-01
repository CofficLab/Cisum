import Foundation
import ProviderStore
import StoreKit
import SwiftUI
import Testing
@testable import ProviderStoreKit

/// Cisum 商店适配层的测试。
///
/// 分层说明：
/// - **通用机制**（交易监听、权益校准、订阅聚合、交易验证）由共享的
///   `KitStoreKit` 承担，另有完整单测，本文件不重复覆盖；
/// - 本文件覆盖 **Cisum 侧**的语义：商品表映射、展示模型、持久化格式、
///   以及 App 独有的订阅组状态查询。
@Suite(.serialized)
struct ProviderStoreKitTests {

    // MARK: - 商品表

    /// 商品表包含全部登记的商品 ID。
    @Test
    func productConfigurationContainsMappedProductIDs() {
        let expectedIDs: Set<String> = [
            "consumable.fuel.octane87",
            "consumable.fuel.octane89",
            "consumable.fuel.octane91",
            "nonconsumable.car",
            "nonconsumable.utilityvehicle",
            "nonconsumable.racecar",
            "com.yueyi.cisum.monthly",
            "com.yueyi.cisum.yearly",
            "com.yueyi.cisum.pro.month.1",
            "com.yueyi.cisum.pro.year.1",
            "com.yueyi.cisum.pro.day.7",
            "com.yueyi.kuaiyizhi.pro.month.1",
            "com.yueyi.kuaiyizhi.pro.year.1",
            "com.yueyi.kuaiyizhi.pro.day.7",
        ]

        #expect(Set(CisumStoreCatalog.shared.allProductIds) == expectedIDs)
    }

    /// 订阅商品映射到 Pro，占位商品不授予任何等级。
    @Test
    func catalogMapsSubscriptionProductsToProTier() {
        #expect(CisumStoreCatalog.shared.tier(for: "com.yueyi.cisum.monthly") == .pro)
        #expect(CisumStoreCatalog.shared.tier(for: "com.yueyi.cisum.yearly") == .pro)
        #expect(CisumStoreCatalog.shared.tier(for: "consumable.fuel.octane87") == .none)
        #expect(CisumStoreCatalog.shared.tier(for: "nonconsumable.car") == .none)
    }

    /// 未经上架的历史别名不应再授予权益。
    ///
    /// `.pro.monthly` / `.pro.yearly` / `.pro.annual` / `.annual` 从未在
    /// App Store Connect 上架过。留在商品表里会让购买面板请求一批永远拿不到
    /// 的商品，并把本地 mock 的档位数量推到 6 行，与生产的 2 行不一致。
    @Test
    func unshippedSubscriptionAliasesGrantNoTier() {
        for productID in [
            "com.yueyi.cisum.pro.monthly",
            "com.yueyi.cisum.pro.yearly",
            "com.yueyi.cisum.pro.annual",
            "com.yueyi.cisum.annual",
        ] {
            #expect(CisumStoreCatalog.shared.tier(for: productID) == .none)
            #expect(!CisumStoreCatalog.shared.allProductIds.contains(productID))
        }
    }

    /// 未登记的商品不授予权益：默认拒绝，而非默认放行。
    @Test
    func unknownProductGrantsNoTier() {
        #expect(CisumStoreCatalog.shared.tier(for: "unknown.product") == .none)
        #expect(CisumStoreCatalog.shared.tier(for: "definitely.not.a.product") == .none)
    }

    /// 付费商品列表排除占位商品。
    ///
    /// 用户买了却发现「还是免费版」是最差的转化结果——商品列表里不该出现
    /// 不提供权益的占位商品。
    @Test
    func subscriptionProductIdsExcludePlaceholders() {
        let ids = Set(CisumStoreCatalog.shared.subscriptionProductIds)

        #expect(ids.contains("com.yueyi.cisum.monthly"))
        #expect(ids.contains("com.yueyi.kuaiyizhi.pro.day.7"))
        #expect(!ids.contains("nonconsumable.car"))
        #expect(!ids.contains("consumable.fuel.octane87"))
    }

    // MARK: - 权益推导

    /// 有 tier 映射的商品正常授予权益。
    @Test
    func mappedProductGrantsTier() {
        let snapshot = CisumStoreCatalog.shared.entitlement(
            activeProductIDs: ["com.yueyi.cisum.yearly"],
            latestExpiration: Date().addingTimeInterval(3600)
        )

        #expect(snapshot.tier == .pro)
        #expect(snapshot.isProOrHigher)
    }

    /// 未登记的商品无法延长付费权益。
    ///
    /// 这是「用户付了钱，权益没到账」的直接守卫：商品表查不到档位时必须
    /// 拒绝放行，无论它排在已购商品之前还是之后。
    @Test
    func unknownProductsCannotExtendPaidEntitlements() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let snapshot = CisumStoreCatalog.shared.entitlement(
            activeProductIDs: ["unknown.subscription", "com.yueyi.cisum.monthly"],
            latestExpiration: now.addingTimeInterval(100)
        )
        #expect(snapshot.tier == .pro)
        #expect(snapshot.expiresAt == now.addingTimeInterval(100))

        // 只有一个未登记商品时，什么权益都拿不到。
        let unknownOnly = CisumStoreCatalog.shared.entitlement(
            activeProductIDs: ["unknown.subscription"],
            latestExpiration: now.addingTimeInterval(10_000)
        )
        #expect(unknownOnly.tier == .none)
        #expect(unknownOnly.expiresAt == nil)
    }

    /// 过期订阅等价于免费档——不是「曾经买过」。
    @Test
    func expiredEntitlementIsTreatedAsFree() {
        // 用真实的过去时刻：快照的过期判定与当前时间比较，
        // 固定时间戳可能落在未来而测不出过期。
        let snapshot = CisumStoreCatalog.shared.entitlement(
            activeProductIDs: ["com.yueyi.cisum.monthly"],
            latestExpiration: Date().addingTimeInterval(-3600)
        )

        #expect(snapshot.tier == .pro)
        #expect(snapshot.isExpired)
        #expect(snapshot.effectiveTier == .none)
        #expect(snapshot.isNotProOrHigher)
    }

    // MARK: - 档位与展示

    /// 档位是有序的：比较运算符直接表达「至少 Pro」这类规则。
    @Test
    func tierOrderingAndFlagsAreStable() {
        #expect(StoreTier.none < StoreTier.pro)
        #expect(StoreTier.pro < StoreTier.ultimate)
        #expect(StoreTier.none.isFree)
        #expect(!StoreTier.pro.isFree)
        #expect(!StoreTier.pro.isUltimateOrHigher)
        #expect(StoreTier.ultimate.isProOrHigher)
        #expect(StoreTier.ultimate.isUltimateOrHigher)
    }

    /// 档位可按原始值编解码，用于缓存与跨进程传递。
    @Test
    func tierRoundTripsThroughCodable() throws {
        for tier in [StoreTier.none, .pro, .ultimate] {
            let data = try JSONEncoder().encode(tier)
            #expect(try JSONDecoder().decode(StoreTier.self, from: data) == tier)
        }
    }

    /// 权益快照保留可选到期时间。
    @Test(arguments: [StoreTier.none, .pro, .ultimate])
    func entitlementSnapshotCodablePreservesOptionalExpiration(tier: StoreTier) throws {
        for expiry in [Optional<Date>.none, Optional(Date(timeIntervalSince1970: 1_800_000_000))] {
            let snapshot = StoreEntitlementSnapshot(tier: tier, expiresAt: expiry)
            let decoded = try JSONDecoder().decode(
                StoreEntitlementSnapshot.self,
                from: JSONEncoder().encode(snapshot)
            )
            #expect(decoded == snapshot)
            if expiry == nil {
                #expect(snapshot.effectiveTier == .none)
                #expect(snapshot.isExpired)
            }
        }
    }

    // MARK: - 展示模型

    /// 商品分组能展平订阅并按组查找。
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

    /// 商品按类别分组。
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

    /// 订阅组按组 ID 聚合，且组内按价格从低到高排序。
    @Test
    func subscriptionGroupsAggregateByGroupIDAndSortByPrice() {
        let cheap = product(id: "cheap", price: 3, groupID: "pro", groupName: "Pro")
        let pricey = product(id: "pricey", price: 20, groupID: "pro", groupName: "Pro")
        let other = product(id: "other", price: 9, groupID: "ultimate", groupName: "Ultimate")

        let groups = ProductGroupsDTO(classifiedProducts: [
            (.autoRenewable, pricey),
            (.autoRenewable, cheap),
            (.autoRenewable, other),
        ])

        #expect(groups.subscriptionGroups.count == 2)
        let pro = groups.subscriptionGroup(withId: "pro")
        #expect(pro?.subscriptions.map(\.id) == ["cheap", "pricey"])
    }

    // MARK: - 持久化

    /// 权益缓存写入后能读回；清除后回到免费档。
    @Test
    func storeStatePersistsAndClearsEntitlement() {
        withPreservedPurchaseCache { defaults in
            let purchaseKey = "store.purchase"
            let checkedKey = "store.lastCheckedAt"

            let active = StoreEntitlementSnapshot(tier: .ultimate, expiresAt: .distantFuture)
            StoreState.update(entitlement: active)

            #expect(StoreService.cachedPurchaseInfo() == active)
            #expect(StoreService.tierCached() == .ultimate)
            #expect(StoreService.expiresAtCached() == .distantFuture)
            #expect(defaults.object(forKey: checkedKey) is Double)

            StoreState.clear()
            #expect(StoreState.cachedPurchaseInfo() == .none)
            #expect(StoreService.tierCached() == .none)

            // 损坏的缓存不应被当成有效权益。
            defaults.set(Data([0xFF]), forKey: purchaseKey)
            #expect(StoreState.cachedPurchaseInfo() == .none)
        }
    }

    /// 缓存访问器反映当前数据，并拒绝非法缓存。
    @Test
    func cachedAccessorsRejectInvalidCache() {
        withPreservedPurchaseCache { defaults in
            let active = StoreEntitlementSnapshot(tier: .ultimate, expiresAt: .distantFuture)
            StoreState.update(entitlement: active)

            #expect(StoreService.cachedPurchaseInfo() == active)
            #expect(StoreService.tierCached() == .ultimate)

            let expired = StoreEntitlementSnapshot(tier: .pro, expiresAt: .distantPast)
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

    // MARK: - 订阅状态查询

    /// 订阅选择能处理重复商品、宽限期与扣款重试。
    @Test
    func subscriptionSelectionHandlesDuplicateProductsGraceAndBillingRetry() {
        let id = "com.yueyi.cisum.monthly"
        let products = [product(id: id, price: 5), product(id: id, price: 7)]

        for state in [RenewalState.inGracePeriod, .inBillingRetryPeriod, .subscribed] {
            let statuses = [status(.revoked, productID: id), status(state, productID: id),
                            status(.subscribed, productID: id)]
            #expect(StoreService.highestActiveSubscriptionStatusIndex(
                subscriptions: products, statuses: statuses) == 1)
        }

        #expect(StoreService.highestActiveSubscriptionStatusIndex(
            subscriptions: products,
            statuses: [status(.expired, productID: id), status(.revoked, productID: id)]) == nil)
    }

    /// 无订阅状态时应回退到 `distantPast`（即视为已过期），而不是 `now`，
    /// 否则一次查询失败就会让用户被误判为付费用户。
    @Test
    func computeExpirationDateFallsBackToDistantPastWithoutStatus() {
        let fallback = StoreService.computeExpirationDate(from: nil)

        #expect(fallback == Date.distantPast)
        #expect(fallback < Date(timeIntervalSince1970: 0))
    }

    // MARK: - 交易校验

    /// verified 结果应原样返回，不得篡改载荷。
    @Test
    func checkVerifiedUnwrapsVerifiedPayload() throws {
        let payload = "safe-value"
        let result = VerificationResult<String>.verified(payload)

        #expect(try StoreService.checkVerified(result) == payload)
    }

    /// `checkVerified` 的 unverified 分支无法在单测中覆盖：
    /// `VerificationResult<T>.VerificationError` 没有公开构造器，
    /// 只能由 StoreKit 在真实验签失败时产生。
    ///
    /// 这里改为锁定「唯一可构造的分支必须成功解包」，避免该函数被误改成静默吞错。
    @Test
    func checkVerifiedOnlyExposesVerifiedBranchInUnitTests() throws {
        // 泛型约束：函数必须对任意可验签类型可用
        func roundTrip<T>(_ value: T) throws -> T {
            try StoreService.checkVerified(VerificationResult<T>.verified(value))
        }

        #expect(try roundTrip(42) == 42)
        #expect(try roundTrip("id") == "id")
        #expect(try roundTrip([1, 2, 3]) == [1, 2, 3])
    }

    // MARK: - 元数据与事件

    /// 错误文案保持用户可读。
    @Test
    func storeErrorMessagesRemainUserReadable() {
        #expect(StoreError.failedVerification.errorDescription?.isEmpty == false)
        #expect(StoreError.canNotGetProducts.errorDescription?.isEmpty == false)
    }

    /// 插件元数据与通知名保持稳定。
    @Test
    func storeMetadataAndNotificationNamesRemainStable() {
        #expect(StorePluginInfo.titleKey == "Store")
        #expect(StorePluginInfo.descriptionKey == "In-App purchases and subscriptions")
        #expect(StorePluginInfo.iconName == "cart")
        #expect(Notification.Name.storeTransactionUpdated.rawValue == "store.transaction.updated")
        #expect(Notification.Name.Restored.rawValue == "store.restored")
    }

    /// SwiftUI 辅助修饰符可用。
    @Test
    func storeViewHelpersRemainUsable() {
        let restoredView = EmptyView().onRestored { _ in }
        let updatedView = EmptyView().onStoreTransactionUpdated { _ in }
        withExtendedLifetime((restoredView, updatedView)) {}
    }

    /// 交易更新通知携带商品 ID。
    @Test
    @MainActor
    func transactionNotificationIncludesProductID() async {
        let productID = "com.yueyi.cisum.monthly"
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

    /// 交易监听只启动一次。
    @Test
    func storeTransactionListenerStartsOnlyOnce() {
        #expect(StoreService.shouldStartTransactionListener(isStarted: false))
        #expect(!StoreService.shouldStartTransactionListener(isStarted: true))
    }
}

// MARK: - Helpers

/// 在保留原缓存的前提下执行断言，避免污染真实 `UserDefaults`。
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

/// 构造一个订阅商品。
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

/// 构造一个订阅状态。
private func status(
    _ state: RenewalState,
    productID: String?
) -> SubscriptionStatusSnapshot {
    SubscriptionStatusSnapshot(state: state.rawValue, currentProductID: productID)
}
