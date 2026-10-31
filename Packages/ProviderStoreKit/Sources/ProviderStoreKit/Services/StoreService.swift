import Foundation
import KitStoreKit
import LumiLoggingKit
import OSLog
import ProviderStore
import StoreKit
import SwiftUI

// MARK: - Typealias

public typealias Transaction = StoreKit.Transaction
public typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
public typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState
public typealias PaymentMode = StoreKit.Product.SubscriptionOffer.PaymentMode

// MARK: - Store Service

/// Cisum 商店服务：把共享的 StoreKit 机制层适配到 Cisum 的档位语义。
///
/// ## 分层
///
/// - **机制**（交易监听、权益校准、商品拉取、购买、恢复、验证）由共享的
///   `KitStoreKit`（`StoreKitService`）提供，三个 App 共用同一份实现；
/// - **语义**（哪个商品对应什么档位、当前是不是有效订阅）由本层负责：
///   机制层只回答「哪些订阅商品在有效期内、最晚到什么时候」，档位映射是
///   Cisum 的商品表说了算。
///
/// 本类型保留 Cisum 独有的展示型查询（订阅组状态、已购分组），这些是
/// Cisum 商店 UI 的需求，不是通用机制。
public enum StoreService: SuperLog {
    public static let emoji = "💰"
    static let verbose = false

    /// 共享机制层实例。
    ///
    /// 惰性创建：构造时需要 `onEntitlementChanged` 回调，回调要把权益变化
    /// 广播给 Cisum 的观察者。
    private static let sharedService: StoreKitService = {
        let configuration = StoreKitConfiguration(
            productIDs: CisumStoreCatalog.shared.allProductIds,
            entitlementStorageKey: StoreState.Keys.purchase,
            lastCheckedAtStorageKey: StoreState.Keys.lastCheckedAt
        )

        return StoreKitService(configuration: configuration) { holding in
            // 机制层的结论 → Cisum 的权益快照（档位映射由 Cisum 商品表决定）。
            let snapshot = CisumStoreCatalog.shared.entitlement(
                activeProductIDs: holding.activeSubscriptionProductIDs,
                latestExpiration: holding.latestExpiration
            )
            StoreState.update(entitlement: snapshot)
            NotificationCenter.default.post(
                name: .storeTransactionUpdated,
                object: holding.activeSubscriptionProductIDs.first
            )
        }
    }()

    // MARK: - Bootstrap

    /// 启动交易监听与初始权益校准。App 启动时调用。
    public static func bootstrap() {
        Task {
            await sharedService.bootstrap()
        }
    }

    /// 交易监听是否应当启动。
    ///
    /// 监听是全局唯一的：重复启动会留下多个后台任务，各自消费
    /// `Transaction.updates`，导致同一笔交易被处理多次。
    static func shouldStartTransactionListener(isStarted: Bool) -> Bool {
        !isStarted
    }

    // MARK: - Public State Accessors

    /// 当前权益快照。
    public static func currentEntitlement() -> StoreEntitlementSnapshot {
        StoreState.cachedPurchaseInfo()
    }

    /// 读取缓存的权益快照。
    public static func cachedPurchaseInfo() -> StoreEntitlementSnapshot {
        StoreState.cachedPurchaseInfo()
    }

    /// 重新从商店校准权益并返回最新快照。
    ///
    /// 校准走共享机制层（`KitStoreKit`），因此与启动时的初始校准是同一套
    /// 逻辑，不会各自漂移。
    public static func getPurchaseInfo() async -> StoreEntitlementSnapshot {
        await sharedService.calibrateFromCurrentEntitlements()
        return StoreState.cachedPurchaseInfo()
    }

    /// 当前生效档位（过期即免费）。
    public static func tierCached() -> StoreTier {
        StoreState.cachedPurchaseInfo().effectiveTier
    }

    /// 从本地缓存读取过期时间。
    public static func expiresAtCached() -> Date? {
        StoreState.cachedPurchaseInfo().expiresAt
    }

    // MARK: - Product Fetching

    /// 获取全部商品（按 Cisum 商品表的 ID 清单）。
    public static func fetchAllProducts() async throws -> ProductGroupsDTO {
        try await requestProducts(productIds: CisumStoreCatalog.shared.allProductIds)
    }

    /// 获取所有订阅组（按订阅组 ID 聚合订阅类商品）。
    public static func fetchAllSubscriptionGroups() async throws -> [SubscriptionGroupDTO] {
        let products = try await fetchAllProducts()
        return products.subscriptionGroups
    }

    /// 按 ID 清单请求商品详情并分类。
    static func requestProducts(productIds: some Sequence<String>) async throws -> ProductGroupsDTO {
        let idsArray = Array(productIds)
        let storeProducts = try await Product.products(for: idsArray)
        return ProductGroupsDTO(products: storeProducts)
    }
    // MARK: - Purchased Fetching

    /// 根据当前账户的交易凭据筛选并归类「已购」产品列表。
    ///
    /// - Parameters:
    ///   - cars: 已获取到的非消耗型（如一次性解锁）产品列表。
    ///   - subscriptions: 已获取到的自动续订订阅产品列表。
    ///   - nonRenewables: 已获取到的非续订订阅产品列表。
    /// - Returns: 按交易凭据过滤后的三类「已购清单」元组。
    public static func fetchPurchasedLists(
        cars: [ProductDTO],
        subscriptions: [ProductDTO],
        nonRenewables: [ProductDTO]
    ) async -> (
        cars: [ProductDTO],
        nonRenewables: [ProductDTO],
        subscriptions: [ProductDTO]
    ) {
        var purchasedCars: [ProductDTO] = []
        var purchasedSubscriptions: [ProductDTO] = []
        var purchasedNonRenewableSubscriptions: [ProductDTO] = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction: Transaction = try checkVerified(result)

                switch transaction.productType {
                case .nonConsumable:
                    if let car = cars.first(where: { $0.id == transaction.productID }) {
                        purchasedCars.append(car)
                    }
                case .nonRenewable:
                    if let nonRenewable = nonRenewables.first(where: { $0.id == transaction.productID }),
                       transaction.productID == "nonRenewing.standard" {
                        let currentDate = Date()
                        if let expirationDate = Calendar(identifier: .gregorian)
                            .date(byAdding: DateComponents(year: 1), to: transaction.purchaseDate),
                            currentDate < expirationDate {
                            purchasedNonRenewableSubscriptions.append(nonRenewable)
                        }
                    }
                case .autoRenewable:
                    if let subscription = subscriptions.first(where: { $0.id == transaction.productID }) {
                        purchasedSubscriptions.append(subscription)
                    }
                default:
                    break
                }
            } catch {
                // Ignore unverified transactions for purchased list calculation.
                continue
            }
        }

        return (
            cars: purchasedCars,
            nonRenewables: purchasedNonRenewableSubscriptions,
            subscriptions: purchasedSubscriptions
        )
    }

    // MARK: - Pay

    /// 发起购买（按商品 ID）。
    @discardableResult
    public static func purchase(_ product: ProductDTO) async throws -> Transaction? {
        let products = try await Product.products(for: [product.id])
        guard let storekitProduct = products.first else { return nil }
        return try await purchase(storekitProduct)
    }

    /// 发起购买（按 StoreKit 商品）。
    private static func purchase(_ product: Product) async throws -> Transaction? {
        if verbose {
            os_log("\(self.t)🏬 Starting purchase")
        }

        #if os(visionOS)
            return nil
        #else
            let result = try await product.purchase()

            switch result {
            case let .success(verification):
                if verbose {
                    os_log("\(self.t)🧐 Purchase succeeded, verifying")
                }
                // Check whether the transaction is verified. If it isn't,
                // this function rethrows the verification error.
                let transaction = try checkVerified(verification)

                if verbose {
                    os_log("\(self.t)✅ Purchase verification succeeded")
                }

                // Update StoreState.
                await updateStoreStateAfterPurchase(transaction)

                // Always finish a transaction.
                await transaction.finish()

                return transaction
            case .userCancelled, .pending:
                if verbose {
                    os_log("\(self.t)Purchase was canceled or is pending")
                }
                return nil
            default:
                if verbose {
                    os_log("\(self.t)Purchase result: \(String(describing: result))")
                }
                return nil
            }
        #endif
    }

    /// 恢复购买。
    public static func restorePurchases() async throws {
        try await sharedService.restorePurchases()
    }

    // MARK: - Store State Updates

    /// 更新 StoreState after a successful purchase.
    private static func updateStoreStateAfterPurchase(_ transaction: Transaction) async {
        let tier = CisumStoreCatalog.shared.tier(for: transaction.productID)
        let expiresAt = transaction.expirationDate

        if verbose {
            os_log("\(self.t)🔄 Updating StoreState")
        }

        await MainActor.run {
            StoreState.update(
                entitlement: StoreEntitlementSnapshot(tier: tier, expiresAt: expiresAt)
            )
            postTransactionUpdated(productID: transaction.productID)
        }
    }

    @MainActor
    static func postTransactionUpdated(productID: String) {
        NotificationCenter.default.post(name: .storeTransactionUpdated, object: productID)
    }

    // MARK: - Verification

    /// 校验 StoreKit 的验证结果。未验证的交易一律拒绝。
    public static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case let .verified(safe):
            return safe
        }
    }

    // MARK: - Subscription Status

    /// Inspects subscription group status and returns useful data: subscription products, status details, and highest-tier entries.
    ///
    /// - Parameters:
    ///   - reason: Call reason used for diagnostics.
    ///   - verbose: Whether detailed logs should be emitted.
    /// - Returns: Tuple `(subscriptions, statuses, highestProduct, highestStatus)`.
    public static func inspectSubscriptionStatus(_ reason: String, verbose: Bool = false) async throws -> (
        subscriptions: [ProductDTO],
        statuses: [StoreSubscriptionStatusDTO],
        highestProduct: ProductDTO?,
        highestStatus: StoreSubscriptionStatusDTO?
    ) {
        if verbose {
            os_log("\(self.t)Checking subscription status, reason: \(reason)")
        }

        let products = try await Self.requestProducts(productIds: CisumStoreCatalog.shared.allProductIds)

        // Get the current subscribable product list.
        let subscriptions = products.subscriptions

        if subscriptions.isEmpty {
            return (subscriptions: [], statuses: [], highestProduct: nil, highestStatus: nil)
        }

        guard let subscription = subscriptions.first,
              let statuses = subscription.subscription?.status else {
            if verbose {
                os_log("\(self.t)Subscription product has no available subscription status")
            }
            return (subscriptions: subscriptions, statuses: [], highestProduct: nil, highestStatus: nil)
        }

        if statuses.isEmpty {
            if verbose {
                os_log("\(self.t)Subscription group currently has no status")
            }
            return (subscriptions: subscriptions, statuses: [], highestProduct: nil, highestStatus: nil)
        }

        if verbose {
            os_log("\(self.t)StoreManager checked subscription status, statuses.count -> \(statuses.count)")
        }

        let snapshots = statuses.map {
            SubscriptionStatusSnapshot(
                state: $0.state,
                currentProductID: $0.currentProductID
            )
        }

        let highestIndex = highestActiveSubscriptionStatusIndex(
            subscriptions: subscriptions,
            statuses: snapshots
        )
        let highestStatus = highestIndex.map { statuses[$0] }
        let productsByID = subscriptionsByID(subscriptions)
        let highestProduct = highestIndex
            .flatMap { snapshots[$0].currentProductID }
            .flatMap { productsByID[$0] }

        return (subscriptions: subscriptions, statuses: statuses, highestProduct: highestProduct, highestStatus: highestStatus)
    }

    static func highestActiveSubscriptionStatusIndex(
        subscriptions: [ProductDTO],
        statuses: [SubscriptionStatusSnapshot]
    ) -> Int? {
        let productsByID = subscriptionsByID(subscriptions)
        var highestIndex: Int?
        var highestTier: StoreTier = .none

        for (index, status) in statuses.enumerated() {
            switch status.state {
            case RenewalState.expired.rawValue,
                 RenewalState.revoked.rawValue:
                continue
            default:
                break
            }

            guard let productID = status.currentProductID,
                  productsByID[productID] != nil else {
                continue
            }

            let tier = CisumStoreCatalog.shared.tier(for: productID)
            if highestIndex == nil || tier > highestTier {
                highestIndex = index
                highestTier = tier
            }
        }

        return highestIndex
    }

    private static func subscriptionsByID(_ subscriptions: [ProductDTO]) -> [String: ProductDTO] {
        subscriptions.reduce(into: [:]) { result, subscription in
            result[subscription.id] = subscription
        }
    }

    /// 计算订阅到期时间（按订阅状态）。
    public static func computeExpirationDate(from status: Product.SubscriptionInfo.Status?) -> Date {
        guard let status = status else {
            return Date.distantPast
        }

        guard case let .verified(renewalInfo) = status.renewalInfo,
              case let .verified(transaction) = status.transaction else {
            return Date.distantPast
        }

        switch status.state {
        case .subscribed:
            if let expirationDate = transaction.expirationDate {
                return expirationDate
            } else {
                return Date.distantPast
            }
        case .expired:
            if let expirationDate = transaction.expirationDate {
                return expirationDate
            }
            return Date.distantPast
        case .revoked:
            return Date.distantPast
        case .inGracePeriod:
            if let untilDate = renewalInfo.gracePeriodExpirationDate {
                return untilDate
            } else {
                return Date.distantPast
            }
        case .inBillingRetryPeriod:
            return Date.now.addingTimeInterval(24 * 3600)
        default:
            return Date.distantPast
        }
    }
}

// MARK: - Subscription Status Snapshot

/// 订阅状态快照（诊断视图用）。
struct SubscriptionStatusSnapshot: Equatable, Sendable {
    let state: RenewalState.RawValue
    let currentProductID: String?
}

// MARK: - Error

public enum StoreError: Error, LocalizedError {
    case failedVerification
    case canNotGetProducts

    public var errorDescription: String? {
        switch self {
        case .failedVerification:
            String(localized: "App Store verification failed", bundle: .module)
        case .canNotGetProducts:
            String(localized: "Could not load products from the App Store", bundle: .module)
        }
    }
}
