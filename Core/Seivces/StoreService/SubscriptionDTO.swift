import Foundation
import StoreKit
import SwiftUI

// MARK: - Subscription DTOs

public struct SubscriptionInfoDTO: Hashable, Sendable {
    public let subscriptionPeriod: StoreSubscriptionPeriodDTO
    public let hasIntroductoryOffer: Bool
    public let promotionalOffersCount: Int
    public let status: [StoreSubscriptionStatusDTO] = []
    public let introductoryOffer: IntroductoryOfferDTO?

    // 订阅组显示名和 ID
    // 专业版的使用权限
    //  按年，ID: com.coffic.pro.year
    //  按月，ID: com.coffic.pro.month
    // 旗舰版的使用权限
    //  按年，ID: com.coffic.ultmate.year
    //  按月，ID: com.coffic.ultmate.month
    // 以上例子中，专业版和旗舰版的使用权限就是订阅组
    public let groupDisplayName: String
    public let groupID: String
}

public struct IntroductoryOfferDTO: Hashable, Sendable {
    public let displayPrice: String
    public let numberOfPeriods: Int
    public let paymentMode: String
    public let subscriptionPeriod: StoreSubscriptionPeriodDTO
}

public struct StoreSubscriptionPeriodDTO: Hashable, Codable, Sendable {
    public let value: Int
    public let unit: String
}

extension Product.SubscriptionPeriod.Unit {
    var description: String {
        switch self {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - Mapping

public extension Product.SubscriptionInfo {
    func toDTO() -> SubscriptionInfoDTO {
        let periodDTO = StoreSubscriptionPeriodDTO(
            value: subscriptionPeriod.value,
            unit: subscriptionPeriod.unit.description
        )

        let introOfferDTO: IntroductoryOfferDTO? = {
            guard let offer = introductoryOffer else { return nil }
            let offerPeriod = StoreSubscriptionPeriodDTO(
                value: offer.period.value,
                unit: offer.period.unit.description
            )
            return IntroductoryOfferDTO(
                displayPrice: offer.displayPrice,
                numberOfPeriods: offer.periodCount,
                paymentMode: offer.paymentMode.rawValue,
                subscriptionPeriod: offerPeriod
            )
        }()

        return SubscriptionInfoDTO(
            subscriptionPeriod: periodDTO,
            hasIntroductoryOffer: (introductoryOffer != nil),
            promotionalOffersCount: promotionalOffers.count,
            introductoryOffer: introOfferDTO,
            groupDisplayName: self.groupDisplayName,
            groupID: self.subscriptionGroupID
        )
    }
}

public struct StoreSubscriptionStatusDTO: Hashable, Sendable {
    public let state: RenewalState.RawValue
    public let currentProductID: String?
    public let isTransactionVerified: Bool
    public let isRenewalInfoVerified: Bool
    public let renewalInfo: VerificationResult<Product.SubscriptionInfo.RenewalInfo>
}

public extension Product.SubscriptionInfo.Status {
    func toDTO() -> StoreSubscriptionStatusDTO {
        let currentProductID: String? = {
            if case let .verified(info) = renewalInfo {
                return info.currentProductID
            }
            return nil
        }()

        let isTransactionVerified: Bool = {
            if case .verified = transaction { return true }
            return false
        }()

        let isRenewalInfoVerified: Bool = {
            if case .verified = renewalInfo { return true }
            return false
        }()

        return StoreSubscriptionStatusDTO(
            state: self.state.rawValue,
            currentProductID: currentProductID,
            isTransactionVerified: isTransactionVerified,
            isRenewalInfoVerified: isRenewalInfoVerified, renewalInfo: self.renewalInfo
        )
    }
}

// MARK: - Preview

#Preview("Debug") {
    DebugView()
        .inRootView()
        .frame(height: 800)
}

#Preview("Buy") {
    PurchaseView()
        .inRootView()
        .frame(height: 800)
}

#Preview("APP") {
    ContentView()
        .inRootView()
        .frame(width: 700)
        .frame(height: 800)
}
