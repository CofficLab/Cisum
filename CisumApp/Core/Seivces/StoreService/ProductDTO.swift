import Foundation
import StoreKit
import SwiftUI

public struct ProductDTO: Identifiable, Hashable, Sendable {
    public enum ProductKind: String, Codable, Sendable {
        case consumable
        case nonConsumable
        case autoRenewable
        case nonRenewable
        case unknown
    }

    public let id: String
    public let displayName: String
    public let displayPrice: String
    public let price: Decimal
    public let kind: ProductKind
    public var description: String = ""
    public let subscription: SubscriptionInfoDTO?

    public init(id: String, displayName: String, displayPrice: String, price: Decimal, kind: ProductKind, subscription: SubscriptionInfoDTO? = nil, description: String) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.price = price
        self.kind = kind
        self.subscription = subscription
        self.description = description
    }

    public static func toDTO(_ product: Product, kind: ProductDTO.ProductKind) -> ProductDTO {
        var subscriptionDTO: SubscriptionInfoDTO?
        if kind == .autoRenewable, let info = product.subscription {
            subscriptionDTO = info.toDTO()
        }

        return ProductDTO(
            id: product.id,
            displayName: product.displayName,
            displayPrice: product.displayPrice,
            price: product.price,
            kind: kind,
            subscription: subscriptionDTO, description: product.description
        )
    }
}

extension Product {
    func toNonConsumableDTO() -> ProductDTO {
        .toDTO(self, kind: .nonConsumable)
    }
}

// MARK: - Preview

#Preview("Debug") {
    DebugView()
        .inRootView()
        .frame(height: 800)
}
