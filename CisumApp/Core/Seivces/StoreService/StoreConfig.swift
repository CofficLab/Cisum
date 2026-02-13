import MagicKit
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
        guard let expiresAt = self.expiresAt else {
            return "nil"
        }

        let timeStr = expiresAt.fullDateTime

        // 延迟1分钟，方便测试
        let isExpired = self.isExpired ? "[过期了]" : "[没过期]"

        return timeStr + isExpired
    }

    public var isExpired: Bool {
        guard let expiresAt = self.expiresAt else {
            return true
        }

        // 延迟1分钟，方便测试
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
            return "免费版"
        case .pro:
            return "专业版"
        case .ultimate:
            return "旗舰版"
        }
    }
}

enum StoreConfig: Sendable {
    // 维护产品ID -> 订阅等级 的映射
    static let productTier: [String: SubscriptionTier] = [
        // Consumables
        "consumable.fuel.octane87": .none,
        "consumable.fuel.octane89": .none,
        "consumable.fuel.octane91": .none,

        // Non-consumables
        "nonconsumable.car": .none,
        "nonconsumable.utilityvehicle": .none,
        "nonconsumable.racecar": .none,

        // subscription
        "com.yueyi.cisum.monthly": .pro,
        "com.yueyi.cisum.yearly": .pro,
    ]

    // 全部商品ID列表（用于请求产品）
    static var allProductIds: [String] {
        Array(productTier.keys)
    }

    // 查询某个产品ID对应的订阅等级
    static func tier(for productId: String) -> SubscriptionTier {
        productTier[productId] ?? .none
    }
}

// MARK: Preview

#if os(macOS)
    #Preview("App - Large") {
        ContentView()
            .inRootView()
            .frame(width: 600, height: 1000)
    }

    #Preview("App - Small") {
        ContentView()
            .inRootView()
            .frame(width: 500, height: 800)
    }
#endif

#if os(iOS)
    #Preview("iPhone") {
        ContentView()
            .inRootView()
    }
#endif
