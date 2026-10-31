import Foundation
import Testing
@testable import ProviderStore

// MARK: - 产品 ID 与等级映射

/// `.storekit` 配置里的每个商品都必须在 `StoreConfig` 里有 tier 映射。
///
/// 缺少映射的后果不是「配置不完整」，而是**用户付了钱权益不到账**：
/// `StoreState.detectedPurchaseInfo` 里 `guard tier > .none else { continue }`
/// 会直接跳过没有映射的商品。
@Test func everyConfiguredSubscriptionGrantsProTier() {
    // 与 `.storekit` 配置保持一致的商品 ID 集合。
    let configuredProductIDs = [
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

    for productID in configuredProductIDs {
        #expect(StoreConfig.tier(for: productID) == .pro, "\(productID) 应当授予 Pro 权益")
        #expect(StoreConfig.allProductIds.contains(productID))
    }
}

/// 占位商品（消耗品 / 非消耗品）不授予任何订阅权益。
@Test func placeholderProductsGrantNoTier() {
    let placeholderProductIDs = [
        "consumable.fuel.octane87",
        "consumable.fuel.octane89",
        "consumable.fuel.octane91",
        "nonconsumable.car",
        "nonconsumable.utilityvehicle",
        "nonconsumable.racecar",
    ]

    for productID in placeholderProductIDs {
        #expect(StoreConfig.tier(for: productID) == .none)
    }
}

/// 未登记的商品 ID 不授予权益（默认拒绝，而非默认放行）。
@Test func unknownProductGrantsNoTier() {
    #expect(StoreConfig.tier(for: "com.example.unknown") == .none)
}

/// 购买面板只展示真正带来权益的商品。
///
/// 用户买了却发现「还是免费版」是最差的转化结果——商品列表里不该出现
/// 不提供权益的占位商品。
@Test func subscriptionProductIdsExcludePlaceholders() {
    let subscriptionIDs = Set(StoreConfig.subscriptionProductIds)

    #expect(subscriptionIDs.contains("com.yueyi.cisum.pro.monthly"))
    #expect(subscriptionIDs.contains("com.yueyi.kuaiyizhi.pro.day.7"))
    #expect(!subscriptionIDs.contains("nonconsumable.car"))
    #expect(!subscriptionIDs.contains("consumable.fuel.octane87"))

    // 每一个能带来权益的商品都必须映射到非 none 的等级。
    for productID in subscriptionIDs {
        #expect(StoreConfig.tier(for: productID) > .none)
    }
}

// MARK: - 权益判定

/// 过期订阅等价于免费档——不是「曾经买过」。
@Test func expiredSubscriptionIsTreatedAsFree() {
    let expired = PurchaseInfo(tier: .pro, expiresAt: Date().addingTimeInterval(-60))
    #expect(expired.isExpired)
    #expect(expired.effectiveTier == .none)
    #expect(expired.isProOrHigher == false)
}

/// 有效订阅保留 Pro 等级。
@Test func activeSubscriptionKeepsProTier() {
    let active = PurchaseInfo(tier: .pro, expiresAt: Date().addingTimeInterval(3600))
    #expect(!active.isExpired)
    #expect(active.effectiveTier == .pro)
    #expect(active.isProOrHigher == true)
}

/// 权益检测会跳过不授予等级的商品。
///
/// 这是「买了不给权益」这条链路的直接守卫：没有 tier 映射的商品
/// 不能影响权益判定。
@Test func entitlementDetectionSkipsProductsWithoutTier() {
    let entitlements = [
        StoreState.EntitlementSnapshot(
            productID: "nonconsumable.car",
            productType: .nonConsumable,
            expirationDate: nil
        ),
        StoreState.EntitlementSnapshot(
            productID: "consumable.fuel.octane87",
            productType: .consumable,
            expirationDate: nil
        ),
    ]

    let detected = StoreState.detectedPurchaseInfo(from: entitlements, now: .now)
    #expect(detected.tier == .none)
}

/// 有 tier 映射的商品正常授予权益。
@Test func entitlementDetectionGrantsTierForMappedProducts() {
    let entitlements = [
        StoreState.EntitlementSnapshot(
            productID: "com.yueyi.cisum.pro.yearly",
            productType: .autoRenewable,
            expirationDate: Date().addingTimeInterval(3600)
        ),
    ]

    let detected = StoreState.detectedPurchaseInfo(from: entitlements, now: .now)
    #expect(detected.tier == .pro)
}
