import Foundation

// MARK: - Store Product Kind

/// 商品类别。
///
/// 与 StoreKit 的商品类型一一对应，但**不引用** StoreKit 类型：Kit 层必须
/// 能在没有 StoreKit 的环境（单元测试、其他平台工具链）下编译。
public enum StoreKitProductType: String, Sendable, Codable, CaseIterable {
    /// 消耗品（可重复购买）。
    case consumable
    /// 非消耗品（一次性解锁，永久有效）。
    case nonConsumable
    /// 自动续期订阅。
    case autoRenewable
    /// 非续期订阅（有固定有效期）。
    case nonRenewable
    /// 未知类别。
    case unknown

    /// 是否为订阅类商品（自动续期或非续期）。
    public var isSubscription: Bool {
        self == .autoRenewable || self == .nonRenewable
    }
}

// MARK: - Store Transaction Summary

/// 交易凭据摘要：把 StoreKit 交易压缩成权益聚合所需的最小信息。
///
/// 存在意义：StoreKit 的 `Transaction` 没有公开构造入口，单测无法构造交易
/// 对象；聚合只用到产品 ID / 产品类型 / 到期时间三个字段，用本摘要承载即可，
/// 从而让聚合逻辑可以被完整单测覆盖。
public struct StoreKitTransactionSummary: Sendable, Equatable {
    /// 商品 ID。
    public let productID: String

    /// 商品类型（消耗品 / 非消耗品 / 自动续期 / 非续期）。
    public let productType: StoreKitProductType

    /// 权益到期时间。
    public let expirationDate: Date?

    /// 购买时间。非续订订阅在缺失到期时间时据此推算有效期。
    public let purchaseDate: Date

    public init(
        productID: String,
        productType: StoreKitProductType,
        expirationDate: Date?,
        purchaseDate: Date
    ) {
        self.productID = productID
        self.productType = productType
        self.expirationDate = expirationDate
        self.purchaseDate = purchaseDate
    }
}

// MARK: - Subscription Holding

/// 订阅持有结论：哪些订阅商品当前有效、最晚到什么时候。
///
/// ## 为什么 Kit 层不知道「档位」
///
/// 档位（Pro / Ultimate）是**产品语义**，属于 Provider 契约层：不同 App 的
/// 档位命名与含义不同，而「哪些订阅在有效期内」是**机制**，各 App 完全一致。
///
/// Kit 层因此只回答机制问题，把「商品 ID → 档位」的映射留给 App：
/// - Kit 层零依赖 Provider 包，方向是 `Provider → Kit` 而非反向；
/// - 各 App 的商品表与档位体系不被共享层污染。
public struct StoreKitSubscriptionHolding: Sendable, Equatable {
    /// 当前有效的订阅商品 ID。
    public let activeSubscriptionProductIDs: [String]

    /// 有效订阅的最晚到期时间；无有效订阅时为 `nil`。
    public let latestExpiration: Date?

    public init(activeSubscriptionProductIDs: [String], latestExpiration: Date?) {
        self.activeSubscriptionProductIDs = activeSubscriptionProductIDs
        self.latestExpiration = latestExpiration
    }

    /// 无任何有效订阅。
    public static let none = StoreKitSubscriptionHolding(
        activeSubscriptionProductIDs: [],
        latestExpiration: nil
    )

    /// 是否持有有效订阅。
    public var hasActiveSubscription: Bool {
        !activeSubscriptionProductIDs.isEmpty
    }
}

// MARK: - Subscription Aggregation

/// 订阅聚合：由交易凭据推导当前有效的订阅持有情况。
///
/// 这是权益判定的**机制内核**，也是最容易被写错的地方，因此抽成纯函数：
/// - 不触碰 StoreKit 运行时，可完整单测；
/// - 三个 App 共用同一份判定，不会各自漂移。
///
/// ## 规则
///
/// 1. 只有**订阅类**商品（自动续期 / 非续期）授予订阅权益；
///    消耗品与非消耗品（一次性解锁）不计入。
/// 2. 多笔交易并存时，到期时间取**最晚**的那个有效值。
/// 3. 已过期的交易不计入有效订阅。
public enum StoreKitSubscriptionAggregator {

    /// 非续订订阅的有效期（当 StoreKit 未提供到期时间时的回退）。
    ///
    /// 非续订订阅是一次性付费、固定期限的权益；StoreKit 通常会给出
    /// `expirationDate`，缺失时按「购买日起一年」推算。
    public static let nonRenewingFallbackDuration: TimeInterval = 365 * 24 * 60 * 60

    /// 由交易凭据聚合出订阅持有情况。
    ///
    /// - Parameters:
    ///   - transactions: 交易凭据摘要列表。
    ///   - now: 当前时间（过期判定基准）。
    public static func aggregate(
        transactions: [StoreKitTransactionSummary],
        now: Date = Date()
    ) -> StoreKitSubscriptionHolding {
        var activeProductIDs: [String] = []
        var latestExpiration: Date?

        for transaction in transactions {
            guard transaction.productType.isSubscription else {
                // 消耗品与一次性解锁不计入订阅权益。
                continue
            }

            guard let expiration = effectiveExpiration(for: transaction, now: now) else {
                // 已过期的交易不贡献有效期。
                continue
            }

            activeProductIDs.append(transaction.productID)
            latestExpiration = max(latestExpiration ?? expiration, expiration)
        }

        return StoreKitSubscriptionHolding(
            activeSubscriptionProductIDs: activeProductIDs,
            latestExpiration: latestExpiration
        )
    }

    /// 计算一笔交易的有效到期时间。
    ///
    /// - Returns: 有效到期时间；已过期或无有效期限时为 `nil`。
    public static func effectiveExpiration(
        for transaction: StoreKitTransactionSummary,
        now: Date
    ) -> Date? {
        let expiration: Date

        switch transaction.productType {
        case .autoRenewable:
            // 自动续期订阅的到期时间由商店给出；缺失即视为无有效期限。
            guard let provided = transaction.expirationDate else { return nil }
            expiration = provided
        case .nonRenewable:
            // 非续订订阅：优先用商店给出的到期时间，缺失时按购买日起一年推算。
            expiration = transaction.expirationDate
                ?? transaction.purchaseDate.addingTimeInterval(nonRenewingFallbackDuration)
        default:
            return nil
        }

        guard expiration > now else { return nil }
        return expiration
    }
}
