import MagicKit
import LumiUI
import SwiftUI

public struct PurchaseInfo: Codable, Equatable, Sendable {
    public let tier: SubscriptionTier
    public let expiresAt: Date?

    public var isProOrHigher: Bool {
        guard tier >= .pro else { return false }
        return self.isExpired == false
    }

    public var isNotProOrHigher: Bool {
        !isProOrHigher
    }

    public var effectiveTier: SubscriptionTier {
        isProOrHigher ? tier : .none
    }

    public var expiresAtString: String {
        guard let expiresAt else { return "nil" }

        let timeStr = expiresAt.fullDateTime

        // Delay by one minute to make testing easier.
        let isExpired = self.isExpired ? "[expired]" : "[active]"

        return timeStr + isExpired
    }

    public var isExpired: Bool {
        guard let expiresAt else { return true }

        // Delay by one minute to make testing easier.
        return expiresAt.distance(to: .now) > 60 ? true : false
    }

    public static let none: PurchaseInfo = PurchaseInfo(tier: .none, expiresAt: nil)
}

public enum SubscriptionTier: Int, Comparable, Sendable, Codable {
    case none = 0
    case pro = 1
    case ultimate = 2

    public static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    public var isFreeVersion: Bool {
        self == .none
    }

    public var isProOrHigher: Bool {
        self >= .pro
    }

    public var isUltimateOrHigher: Bool {
        self >= .ultimate
    }

    public var displayName: String {
        switch self {
        case .none:
            return String(localized: "Free version", bundle: .module)
        case .pro:
            return String(localized: "Pro version", bundle: .module)
        case .ultimate:
            return String(localized: "Ultimate version", bundle: .module)
        }
    }
}

/// 商店配置：**商品 ID → 订阅等级**的唯一真值源。
///
/// ## 为什么这里是唯一真值源
///
/// 商品 ID 集合历史上散落三处（`StoreConfig`、两份 `.storekit`、`Products.plist`），
/// 各自漂移。漂移的后果不是「配置不好看」，而是**付费链路静默断裂**：
///
/// - 商品在 `.storekit` 里但不在 `productTier` 里 → `tier(for:)` 返回 `.none`
///   → `StoreState.detectedPurchaseInfo` 的 `guard tier > .none else { continue }`
///   直接跳过 → **用户付了钱，权益没到账**；
/// - 商品在 `productTier` 里但线上没有 → `Product.products(for:)` 请求失败
///   → 购买面板加载不出来。
///
/// 因此这里只保留**一份** ID 集合，并用测试守住它与 `.storekit` 配置一致。
enum StoreConfig: Sendable {
    /// 商品 ID → 订阅等级。
    ///
    /// - `.pro`：授予 Pro 权益（解除仓库容量限制等）。
    /// - `.none`：不授予任何等级。消耗品与非消耗品占位商品属于这一类——
    ///   它们不提供订阅权益，列出它们只是为了在配置里保留位置。
    static let productTier: [String: SubscriptionTier] = [
        // Consumables
        "consumable.fuel.octane87": .none,
        "consumable.fuel.octane89": .none,
        "consumable.fuel.octane91": .none,

        // Non-consumables
        "nonconsumable.car": .none,
        "nonconsumable.utilityvehicle": .none,
        "nonconsumable.racecar": .none,

        // Auto-renewable subscriptions — Cisum
        "com.yueyi.cisum.pro.monthly": .pro,
        "com.yueyi.cisum.monthly": .pro,
        "com.yueyi.cisum.pro.yearly": .pro,
        "com.yueyi.cisum.yearly": .pro,
        "com.yueyi.cisum.pro.annual": .pro,
        "com.yueyi.cisum.annual": .pro,

        // Non-renewing subscriptions — Cisum
        "com.yueyi.cisum.pro.month.1": .pro,
        "com.yueyi.cisum.pro.year.1": .pro,
        "com.yueyi.cisum.pro.day.7": .pro,

        // Non-renewing subscriptions — 快易知（同一订阅体系的历史商品 ID）
        //
        // 这些 ID 必须在映射里：`.storekit` 配置里存在它们，若缺少映射则
        // `tier(for:)` 返回 `.none`，用户购买后权益不会授予。
        "com.yueyi.kuaiyizhi.pro.month.1": .pro,
        "com.yueyi.kuaiyizhi.pro.year.1": .pro,
        "com.yueyi.kuaiyizhi.pro.day.7": .pro,
    ]

    /// All product IDs used for product requests.
    static var allProductIds: [String] {
        Array(productTier.keys)
    }

    /// 授予 Pro 权益的商品 ID。
    ///
    /// 购买面板据此决定展示哪些商品——只展示真正能带来权益的商品，
    /// 避免用户买了却发现「还是免费版」。
    static var subscriptionProductIds: [String] {
        productTier
            .filter { $0.value > .none }
            .map(\.key)
            .sorted()
    }

    /// Looks up the subscription tier for a product ID.
    static func tier(for productId: String) -> SubscriptionTier {
        productTier[productId] ?? .none
    }
}

// MARK: Preview
