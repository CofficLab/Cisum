import Foundation
import Testing
@testable import KitStoreKit

/// 订阅聚合的判定内核测试。
///
/// 这是付费链路最容易写错的地方：写错一次就是「用户付了钱，权益没到账」
/// 或「免费用户白嫖付费功能」。因此这些规则逐条锁定。
@Suite("StoreKitSubscriptionAggregator")
struct StoreKitSubscriptionAggregatorTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// 构造一笔交易摘要。
    private func transaction(
        productID: String,
        type: StoreKitProductType,
        expirationDate: Date? = nil,
        purchaseDate: Date? = nil
    ) -> StoreKitTransactionSummary {
        StoreKitTransactionSummary(
            productID: productID,
            productType: type,
            expirationDate: expirationDate,
            purchaseDate: purchaseDate ?? now.addingTimeInterval(-3600)
        )
    }

    // MARK: - 基本判定

    /// 自动续期订阅计入有效订阅。
    @Test func autoRenewableCountsAsActiveSubscription() {
        let result = StoreKitSubscriptionAggregator.aggregate(
            transactions: [
                transaction(
                    productID: "com.example.pro.yearly",
                    type: .autoRenewable,
                    expirationDate: now.addingTimeInterval(3600)
                )
            ],
            now: now
        )

        #expect(result.hasActiveSubscription)
        #expect(result.activeSubscriptionProductIDs == ["com.example.pro.yearly"])
        #expect(result.latestExpiration == now.addingTimeInterval(3600))
    }

    /// 消耗品不计入订阅权益。
    @Test func consumableDoesNotCountAsSubscription() {
        let result = StoreKitSubscriptionAggregator.aggregate(
            transactions: [transaction(productID: "com.example.fuel", type: .consumable)],
            now: now
        )

        #expect(!result.hasActiveSubscription)
        #expect(result.latestExpiration == nil)
    }

    /// 一次性解锁（非消耗品）不计入订阅权益。
    @Test func nonConsumableDoesNotCountAsSubscription() {
        let result = StoreKitSubscriptionAggregator.aggregate(
            transactions: [transaction(productID: "com.example.car", type: .nonConsumable)],
            now: now
        )

        #expect(!result.hasActiveSubscription)
    }

    /// 没有交易时无有效订阅。
    @Test func noTransactionsYieldNoSubscription() {
        let result = StoreKitSubscriptionAggregator.aggregate(transactions: [], now: now)

        #expect(!result.hasActiveSubscription)
        #expect(result.latestExpiration == nil)
    }

    // MARK: - 多笔交易

    /// 多笔交易并存时，到期时间取最晚的那个。
    @Test func multipleTransactionsTakeLatestExpiration() {
        let result = StoreKitSubscriptionAggregator.aggregate(
            transactions: [
                transaction(
                    productID: "com.example.pro.monthly",
                    type: .autoRenewable,
                    expirationDate: now.addingTimeInterval(3600)
                ),
                transaction(
                    productID: "com.example.pro.yearly",
                    type: .autoRenewable,
                    expirationDate: now.addingTimeInterval(7200)
                )
            ],
            now: now
        )

        #expect(result.latestExpiration == now.addingTimeInterval(7200))
        #expect(result.activeSubscriptionProductIDs.count == 2)
    }

    // MARK: - 过期处理

    /// 已过期的自动续期订阅不计入。
    @Test func expiredAutoRenewableIsNotActive() {
        let result = StoreKitSubscriptionAggregator.aggregate(
            transactions: [
                transaction(
                    productID: "com.example.pro.yearly",
                    type: .autoRenewable,
                    expirationDate: now.addingTimeInterval(-3600)
                )
            ],
            now: now
        )

        #expect(!result.hasActiveSubscription)
        #expect(result.latestExpiration == nil)
    }

    /// 已过期的非续订订阅不计入。
    @Test func expiredNonRenewableIsNotActive() {
        let result = StoreKitSubscriptionAggregator.aggregate(
            transactions: [
                transaction(
                    productID: "com.example.pro.monthly",
                    type: .nonRenewable,
                    expirationDate: now.addingTimeInterval(-3600)
                )
            ],
            now: now
        )

        #expect(!result.hasActiveSubscription)
    }

    /// 自动续期订阅缺失到期时间时不推算有效期。
    ///
    /// 自动续期的到期时间由商店给出；缺失时按「购买日起一年」推算会凭空
    /// 造出一段本不存在的有效期。
    @Test func autoRenewableWithoutExpirationDoesNotInferDuration() {
        let result = StoreKitSubscriptionAggregator.aggregate(
            transactions: [
                transaction(
                    productID: "com.example.pro.yearly",
                    type: .autoRenewable,
                    expirationDate: nil,
                    purchaseDate: now.addingTimeInterval(-3600)
                )
            ],
            now: now
        )

        #expect(!result.hasActiveSubscription)
        #expect(result.latestExpiration == nil)
    }

    /// 非续订订阅缺失到期时间时按购买日起一年推算。
    @Test func nonRenewableWithoutExpirationInfersOneYear() {
        let purchaseDate = now.addingTimeInterval(-3600)
        let result = StoreKitSubscriptionAggregator.aggregate(
            transactions: [
                transaction(
                    productID: "com.example.pro.monthly",
                    type: .nonRenewable,
                    expirationDate: nil,
                    purchaseDate: purchaseDate
                )
            ],
            now: now
        )

        let expected = purchaseDate.addingTimeInterval(365 * 24 * 60 * 60)
        #expect(result.latestExpiration == expected)
        #expect(result.hasActiveSubscription)
    }

    /// 非续订订阅的推算到期时间已过时不再计入。
    @Test func nonRenewableWithExpiredInferredDurationIsNotActive() {
        // 两年前购买 → 按「一年有效期」推算已过期。
        let purchaseDate = now.addingTimeInterval(-2 * 365 * 24 * 60 * 60)
        let result = StoreKitSubscriptionAggregator.aggregate(
            transactions: [
                transaction(
                    productID: "com.example.pro.monthly",
                    type: .nonRenewable,
                    expirationDate: nil,
                    purchaseDate: purchaseDate
                )
            ],
            now: now
        )

        #expect(!result.hasActiveSubscription)
    }

    // MARK: - 到期时间计算

    /// 自动续期订阅使用商店给出的到期时间。
    @Test func autoRenewableUsesProvidedExpiration() {
        let expiration = now.addingTimeInterval(3600)
        let transaction = StoreKitTransactionSummary(
            productID: "com.example.pro.yearly",
            productType: .autoRenewable,
            expirationDate: expiration,
            purchaseDate: now
        )

        let result = StoreKitSubscriptionAggregator.effectiveExpiration(for: transaction, now: now)

        #expect(result == expiration)
    }

    /// 非消耗品没有有效到期时间。
    @Test func nonConsumableHasNoEffectiveExpiration() {
        let transaction = StoreKitTransactionSummary(
            productID: "com.example.car",
            productType: .nonConsumable,
            expirationDate: now.addingTimeInterval(3600),
            purchaseDate: now
        )

        let result = StoreKitSubscriptionAggregator.effectiveExpiration(for: transaction, now: now)

        #expect(result == nil)
    }

    /// 订阅类商品的判定。
    @Test func subscriptionTypeDetection() {
        #expect(StoreKitProductType.autoRenewable.isSubscription)
        #expect(StoreKitProductType.nonRenewable.isSubscription)
        #expect(!StoreKitProductType.consumable.isSubscription)
        #expect(!StoreKitProductType.nonConsumable.isSubscription)
        #expect(!StoreKitProductType.unknown.isSubscription)
    }
}
