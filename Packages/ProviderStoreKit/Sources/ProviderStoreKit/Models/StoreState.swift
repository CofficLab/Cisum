import Foundation
import LumiUI
import MagicKit
import OSLog
import ProviderStore
import StoreKit
import SwiftUI

/// Cisum 权益缓存：把权益快照持久化到 `UserDefaults`。
///
/// 共享的 `KitStoreKit` 负责**机制**（何时校准、如何读交易），本类型负责
/// **Cisum 侧的持久化格式与展示语义**（档位显示名、到期时间字符串）。
final class StoreState: ObservableObject, SuperLog {
    nonisolated static let emoji = "💰"

    static let verbose = false

    struct EntitlementSnapshot {
        let productID: String
        let productType: Product.ProductType
        let expirationDate: Date?
    }

    // MARK: - Keys

    /// 持久化 key。
    ///
    /// 与共享机制层共用同一组 key，保证两边读到的是同一份缓存。
    enum Keys {
        static let purchase = "store.purchase"
        static let lastCheckedAt = "store.lastCheckedAt"
    }

    // MARK: - Public API

    /// 读取缓存的权益快照。
    static func cachedPurchaseInfo() -> StoreEntitlementSnapshot {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Keys.purchase),
           let snapshot = try? JSONDecoder().decode(StoreEntitlementSnapshot.self, from: data) {
            return snapshot
        }
        return .none
    }

    /// 写入权益快照。
    static func update(entitlement: StoreEntitlementSnapshot) {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(entitlement) {
            defaults.set(data, forKey: Keys.purchase)
        }
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastCheckedAt)

        if self.verbose {
            os_log("\(self.t)🍋 Updated tier=\(entitlement.tier.rawValue), expiresAt=\(entitlement.expiresAtString)")
        }
    }

    /// 清除权益缓存。
    static func clear() {
        update(entitlement: .none)
    }
}

// MARK: - Tier Display

extension StoreTier {
    /// 档位显示名。
    ///
    /// 展示文案属于 App 侧（本包持有本地化资源），因此不放在共享契约层。
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

extension StoreEntitlementSnapshot {
    /// 到期时间的展示字符串。
    public var expiresAtString: String {
        guard let expiresAt else { return "nil" }

        let timeStr = expiresAt.fullDateTime

        // Delay by one minute to make testing easier.
        let isExpired = self.isExpired ? "[expired]" : "[active]"

        return timeStr + isExpired
    }
}
