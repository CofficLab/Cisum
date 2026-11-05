import Foundation
import SwiftUI

public struct SubscriptionGroupDTO: Hashable, Sendable {
    public let name: String
    public let id: String
    public let subscriptions: [ProductDTO]
}
