import CisumUIComponents
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
        guard let expiresAt = self.expiresAt else {
            return "nil"
        }

        let timeStr = expiresAt.fullDateTime

        // Delay by one minute to make testing easier.
        let isExpired = self.isExpired ? "[expired]" : "[active]"

        return timeStr + isExpired
    }

    public var isExpired: Bool {
        guard let expiresAt = self.expiresAt else {
            return true
        }

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

enum StoreConfig: Sendable {
    // Maintains the product ID to subscription tier mapping.
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
        "com.yueyi.cisum.pro.monthly": .pro,
        "com.yueyi.cisum.monthly": .pro,
        "com.yueyi.cisum.pro.yearly": .pro,
        "com.yueyi.cisum.yearly": .pro,
        "com.yueyi.cisum.pro.annual": .pro,
        "com.yueyi.cisum.annual": .pro,
        "com.yueyi.cisum.pro.month.1": .pro,
        "com.yueyi.cisum.pro.year.1": .pro,
        "com.yueyi.cisum.pro.day.7": .pro,
    ]

    // All product IDs used for product requests.
    static var allProductIds: [String] {
        Array(productTier.keys)
    }

    // Looks up the subscription tier for a product ID.
    static func tier(for productId: String) -> SubscriptionTier {
        productTier[productId] ?? .none
    }
}

// MARK: Preview
