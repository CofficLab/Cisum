import Foundation
import CisumUIComponents
import OSLog
import StoreKit
import SwiftUI

final class StoreState: ObservableObject, SuperLog {
    nonisolated static let emoji = "💰"

    static let verbose = false

    struct EntitlementSnapshot {
        let productID: String
        let productType: Product.ProductType
        let expirationDate: Date?
    }

    // MARK: - Keys

    private enum Keys {
        static let purchase = "store.purchase"
        static let lastCheckedAt = "store.lastCheckedAt"
    }

    // MARK: - Public API

    static func cachedPurchaseInfo() -> PurchaseInfo {
        // Read the persisted structure directly from UserDefaults.
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Keys.purchase),
           let e = try? JSONDecoder().decode(PurchaseInfo.self, from: data) {
            return e
        }
        return .none
    }

    static func update(entitlement: PurchaseInfo) {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(entitlement) {
            defaults.set(data, forKey: Keys.purchase)
        }
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastCheckedAt)

        if self.verbose {
            os_log("\(self.t)🍋 Updated tier=\(entitlement.tier.rawValue), expiresAt=\(entitlement.expiresAtString)")
        }
    }

    static func clear() {
        update(entitlement: .none)
    }

    static func nonRenewableEntitlementInfo(
        productID: String,
        expirationDate: Date?,
        now: Date
    ) -> PurchaseInfo? {
        guard let expirationDate, expirationDate > now else { return nil }
        return PurchaseInfo(
            tier: StoreService.tier(for: productID),
            expiresAt: expirationDate
        )
    }

    static func detectedPurchaseInfo(
        from entitlements: [EntitlementSnapshot],
        now: Date
    ) -> PurchaseInfo {
        var detectedTier: SubscriptionTier = .none
        var detectedExpiration: Date?

        for entitlement in entitlements {
            switch entitlement.productType {
            case .autoRenewable:
                let tier = StoreService.tier(for: entitlement.productID)
                detectedTier = max(detectedTier, tier)
                if let expirationDate = entitlement.expirationDate {
                    detectedExpiration = max(detectedExpiration ?? expirationDate, expirationDate)
                    if verbose {
                        os_log("\(self.t)⏰ Expiration date: \(expirationDate.fullDateTime)")
                    }
                }
                if verbose {
                    os_log("\(self.t)✅ Auto-renewable subscription: \(entitlement.productID), tier: \(tier.rawValue)")
                }
            case .nonRenewable:
                guard let info = nonRenewableEntitlementInfo(
                    productID: entitlement.productID,
                    expirationDate: entitlement.expirationDate,
                    now: now
                ) else {
                    if verbose, let expirationDate = entitlement.expirationDate {
                        os_log("\(self.t)⚠️ Non-renewing subscription expired: \(expirationDate.fullDateTime)")
                    }
                    continue
                }

                detectedTier = max(detectedTier, info.tier)
                if let expirationDate = info.expiresAt {
                    detectedExpiration = max(detectedExpiration ?? expirationDate, expirationDate)
                }
                if verbose {
                    os_log("\(self.t)✅ Non-renewing subscription: \(entitlement.productID), tier: \(info.tier.rawValue)")
                    if let expirationDate = info.expiresAt {
                        os_log("\(self.t)⏰ Non-renewing subscription expiration date: \(expirationDate.fullDateTime)")
                    }
                }
            default:
                if verbose {
                    os_log("\(self.t)⏭️ Skipping other product type: \(entitlement.productID)")
                }
            }
        }

        return PurchaseInfo(tier: detectedTier, expiresAt: detectedExpiration)
    }

    // Calibrate local state from current entitlements.
    static func calibrateFromCurrentEntitlements() async {
        var entitlements: [EntitlementSnapshot] = []

        if self.verbose {
            os_log("\(self.t)🔄 Calibrating current entitlements")
        }

        for await result in StoreKit.Transaction.currentEntitlements {
            guard case let .verified(transaction) = result else {
                if self.verbose {
                    os_log("\(self.t)⚠️ Skipping unverified transaction")
                }
                continue
            }

            if self.verbose {
                os_log("\(self.t)📋 Checking transaction: \(transaction.productID), type: \(transaction.productType.rawValue)")
            }
            entitlements.append(EntitlementSnapshot(
                productID: transaction.productID,
                productType: transaction.productType,
                expirationDate: transaction.expirationDate
            ))
        }

        let detectedEntitlement = detectedPurchaseInfo(from: entitlements, now: .now)
        if self.verbose {
            os_log("\(self.t)🎯 Calibration result: detectedTier=\(detectedEntitlement.tier.rawValue), detectedExpire=\(detectedEntitlement.expiresAt?.description ?? "nil")")
        }

        // Update state on the main thread.
        await MainActor.run {
            update(entitlement: detectedEntitlement)
        }
    }
}
