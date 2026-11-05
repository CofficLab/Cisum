import Foundation

// MARK: - Store Configuration

/// 商店配置：Kit 层运行所需的 App 注入项。
///
/// ## 为什么需要注入
///
/// Kit 层**不含任何 App 专属商品 ID**——商品 ID 清单与持久化 key 都由各 App
/// 提供。原因：
/// - 商品 ID 属于 App 的商店后台配置，Kit 层写死一份就等于替各 App 决定了
///   商品体系，后续任何一方调整商品都会连带影响另外两方；
/// - 持久化 key 若 Kit 层写死，多个 App 装在同一台设备上会互相覆盖权益缓存。
public struct StoreKitConfiguration: Sendable {

    /// 要请求的商品 ID 清单。
    ///
    /// Kit 层只负责「按这份清单向商店请求商品」，不解释清单的语义
    /// （哪个商品对应什么档位由 App 自己决定）。
    public let productIDs: [String]

    /// 权益到期时间的持久化 key。
    public let entitlementStorageKey: String

    /// 「上次校准时间」的持久化 key。
    public let lastCheckedAtStorageKey: String

    /// 权益存储介质。
    ///
    /// 默认用 `UserDefaults.standard`。App 若需要 iCloud 同步或自定义容器，
    /// 可注入自己的实现。
    public let entitlementStorage: any StoreKitEntitlementStoring

    /// 非续订订阅的有效期（秒）。默认一年。
    public let nonRenewingDuration: TimeInterval

    public init(
        productIDs: [String],
        entitlementStorageKey: String = "store.purchase",
        lastCheckedAtStorageKey: String = "store.lastCheckedAt",
        entitlementStorage: any StoreKitEntitlementStoring = UserDefaultsStoreKitEntitlementStorage(),
        nonRenewingDuration: TimeInterval = StoreKitSubscriptionAggregator.nonRenewingFallbackDuration
    ) {
        self.productIDs = productIDs
        self.entitlementStorageKey = entitlementStorageKey
        self.lastCheckedAtStorageKey = lastCheckedAtStorageKey
        self.entitlementStorage = entitlementStorage
        self.nonRenewingDuration = nonRenewingDuration
    }
}

// MARK: - Entitlement Storage

/// 权益存储介质：读写到期时间与校准时间。
///
/// 抽成协议的理由：`UserDefaults` 是全局单例，单元测试里读写真实
/// `UserDefaults` 会互相污染；且 App 未来若要 iCloud 同步权益，需要替换实现。
public protocol StoreKitEntitlementStoring: Sendable {
    /// 读取持久化的权益到期时间。
    func loadExpiration() -> Date?

    /// 持久化权益到期时间。
    func saveExpiration(_ date: Date)

    /// 清除持久化的权益到期时间。
    func clearExpiration()

    /// 读取上次校准时间。
    func loadLastCheckedAt() -> Date?

    /// 记录本次校准时间。
    func saveLastCheckedAt(_ date: Date)
}

// MARK: - UserDefaults Storage

/// 基于 `UserDefaults` 的权益存储实现。
public final class UserDefaultsStoreKitEntitlementStorage: StoreKitEntitlementStoring, @unchecked Sendable {

    private let defaults: UserDefaults
    private let entitlementKey: String
    private let lastCheckedAtKey: String

    public init(
        defaults: UserDefaults = .standard,
        entitlementKey: String = "store.purchase",
        lastCheckedAtKey: String = "store.lastCheckedAt"
    ) {
        self.defaults = defaults
        self.entitlementKey = entitlementKey
        self.lastCheckedAtKey = lastCheckedAtKey
    }

    public func loadExpiration() -> Date? {
        guard let data = defaults.data(forKey: entitlementKey) else { return nil }
        return try? JSONDecoder().decode(Date.self, from: data)
    }

    public func saveExpiration(_ date: Date) {
        guard let data = try? JSONEncoder().encode(date) else { return }
        defaults.set(data, forKey: entitlementKey)
    }

    public func clearExpiration() {
        defaults.removeObject(forKey: entitlementKey)
    }

    public func loadLastCheckedAt() -> Date? {
        let timestamp = defaults.double(forKey: lastCheckedAtKey)
        // double 的 0 值表示「从未写入」，不能当日期用。
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    public func saveLastCheckedAt(_ date: Date) {
        defaults.set(date.timeIntervalSince1970, forKey: lastCheckedAtKey)
    }
}
