import Foundation
import StoreKit
import SwiftUI

public struct ProductGroupsDTO: Hashable, Sendable {
    public let cars: [ProductDTO]
    public let subscriptionGroups: [SubscriptionGroupDTO]
    public let nonRenewables: [ProductDTO]
    public let fuel: [ProductDTO]

    public init(cars: [ProductDTO], subscriptionGroups: [SubscriptionGroupDTO], nonRenewables: [ProductDTO], fuel: [ProductDTO]) {
        self.cars = cars
        self.subscriptionGroups = subscriptionGroups
        self.nonRenewables = nonRenewables
        self.fuel = fuel
    }

    public init(cars: [Product], subscriptions: [Product], nonRenewables: [Product], fuel: [Product]) {
        self.cars = cars.map { ProductDTO.toDTO($0, kind: .nonConsumable) }

        // 将订阅产品按组聚合
        let subscriptionDTOs = subscriptions.map { ProductDTO.toDTO($0, kind: .autoRenewable) }
        self.subscriptionGroups = Self.createSubscriptionGroups(from: subscriptionDTOs)

        self.nonRenewables = nonRenewables.map { ProductDTO.toDTO($0, kind: .nonRenewable) }
        self.fuel = fuel.map { ProductDTO.toDTO($0, kind: .consumable) }
    }

    public init(products: [Product]) {
        let classifiedProducts = products.compactMap { product -> (ProductDTO.ProductKind, ProductDTO)? in
            switch product.type {
            case .consumable:
                return (.consumable, ProductDTO.toDTO(product, kind: .consumable))
            case .nonConsumable:
                return (.nonConsumable, ProductDTO.toDTO(product, kind: .nonConsumable))
            case .autoRenewable:
                return (.autoRenewable, ProductDTO.toDTO(product, kind: .autoRenewable))
            case .nonRenewable:
                return (.nonRenewable, ProductDTO.toDTO(product, kind: .nonRenewable))
            default:
                return nil
            }
        }

        self.init(classifiedProducts: classifiedProducts)
    }

    init(classifiedProducts: [(kind: ProductDTO.ProductKind, product: ProductDTO)]) {
        var cars: [ProductDTO] = []
        var subscriptions: [ProductDTO] = []
        var nonRenewables: [ProductDTO] = []
        var fuel: [ProductDTO] = []

        for (kind, product) in classifiedProducts {
            switch kind {
            case .nonConsumable:
                cars.append(product)
            case .autoRenewable:
                subscriptions.append(product)
            case .nonRenewable:
                nonRenewables.append(product)
            case .consumable:
                fuel.append(product)
            case .unknown:
                break
            }
        }

        self.cars = cars
        self.subscriptionGroups = Self.createSubscriptionGroups(from: subscriptions)
        self.nonRenewables = nonRenewables
        self.fuel = fuel
    }
}

// MARK: - Subscription Groups

extension ProductGroupsDTO {
    /// 创建订阅组（按订阅组 ID 聚合订阅类商品）
    ///
    /// - Parameter subscriptions: 订阅产品列表
    /// - Returns: 订阅组列表：`[SubscriptionGroupDTO]`
    static func createSubscriptionGroups(from subscriptions: [ProductDTO]) -> [SubscriptionGroupDTO] {
        // 按订阅组 ID 聚合，避免为同一组重复创建条目
        var grouped: [String: [ProductDTO]] = [:]
        for product in subscriptions {
            let groupId = product.subscription?.groupID ?? "unknown"
            grouped[groupId, default: []].append(product)
        }

        // 组名优先取 StoreKit 的显示名，其次回退为组 ID
        let groups: [SubscriptionGroupDTO] = grouped.map { groupId, items in
            let nameFromProduct = items.first?.subscription?.groupDisplayName
            let displayName = nameFromProduct ?? groupId

            // 按价格从低到高排序订阅产品
            let sortedItems = items.sorted { (first: ProductDTO, second: ProductDTO) in
                first.price < second.price
            }

            return SubscriptionGroupDTO(name: displayName, id: groupId, subscriptions: sortedItems)
        }
        .sorted { $0.id < $1.id }

        return groups
    }

    /// 获取所有订阅产品（扁平化所有订阅组中的订阅）
    ///
    /// - Returns: 所有订阅产品的列表
    public var subscriptions: [ProductDTO] {
        return subscriptionGroups.flatMap { $0.subscriptions }
    }

    /// 根据订阅组 ID 查找订阅组
    ///
    /// - Parameter groupId: 订阅组 ID
    /// - Returns: 对应的订阅组，如果不存在则返回 nil
    public func subscriptionGroup(withId groupId: String) -> SubscriptionGroupDTO? {
        return subscriptionGroups.first { $0.id == groupId }
    }
}
