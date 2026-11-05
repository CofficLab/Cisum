import Foundation
import LumiLoggingKit
import StoreKit
import os
#if os(visionOS)
import UIKit
#endif

// MARK: - Store Error

/// 商店操作错误。
public enum StoreKitError: Error, LocalizedError, Sendable {
    /// 交易验证失败（StoreKit 返回未验证的交易）。
    case failedVerification
    /// 无法从 App Store 拉取商品。
    case canNotGetProducts
    /// 商品不存在（按 ID 请求时）。
    case productNotFound(String)
    /// visionOS 上发起购买时缺少承载购买面板的 `UIScene`。
    case purchaseRequiresScene

    public var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "App Store verification failed"
        case .canNotGetProducts:
            return "Could not load products from the App Store"
        case let .productNotFound(productID):
            return "Product not found in the App Store: \(productID)"
        case .purchaseRequiresScene:
            return "A scene is required to present the purchase sheet"
        }
    }
}

// MARK: - Store Product

/// StoreKit 商品的中立描述。
///
/// Kit 层内部用 `StoreKit.Product`，但对外只暴露这个值类型：`Product` 是
/// 引用类型、不可 `Sendable`、且绑定 StoreKit 框架，不适合作为对外载荷。
public struct StoreKitProductInfo: Identifiable, Sendable, Equatable {
    /// 商品 ID。
    public let id: String
    /// 展示名称。
    public let displayName: String
    /// 本地化价格字符串。
    public let displayPrice: String
    /// 商品类别。
    public let kind: StoreKitProductType
    /// 商品描述。
    public let productDescription: String
    /// 订阅商品所属的订阅组名。
    public let subscriptionGroupName: String?
    /// 订阅商品所属的订阅组 ID。
    public let subscriptionGroupID: String?
    /// 订阅周期描述（如 `1 month`）。
    public let subscriptionPeriodDescription: String?
    /// 是否有试用优惠。
    public let hasIntroductoryOffer: Bool

    /// 由 `StoreKit.Product` 构造。
    public init(product: Product) {
        self.id = product.id
        self.displayName = product.displayName
        self.displayPrice = product.displayPrice
        self.productDescription = product.description
        self.kind = StoreKitProductType(product.type)
        self.subscriptionGroupName = product.subscription?.groupDisplayName
        self.subscriptionGroupID = product.subscription?.subscriptionGroupID
        self.subscriptionPeriodDescription = product.subscription.map {
            "\($0.subscriptionPeriod.value) \(Self.periodUnitDescription($0.subscriptionPeriod.unit))"
        }
        self.hasIntroductoryOffer = product.subscription?.introductoryOffer != nil
    }

    /// 订阅周期单位描述。
    static func periodUnitDescription(_ unit: Product.SubscriptionPeriod.Unit) -> String {
        switch unit {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        @unknown default: return "unknown"
        }
    }
}

public extension StoreKitProductType {
    /// StoreKit 商品类型 → 中立类别。
    init(_ type: Product.ProductType) {
        switch type {
        case .consumable: self = .consumable
        case .nonConsumable: self = .nonConsumable
        case .autoRenewable: self = .autoRenewable
        case .nonRenewable: self = .nonRenewable
        default: self = .unknown
        }
    }
}

// MARK: - Store Service

/// StoreKit 2 生命周期实现：交易监听、权益校准、商品拉取、购买与恢复。
///
/// ## 与 App 的关系
///
/// Kit 层负责**机制**，App 负责**配置与语义**：
/// - 商品 ID 清单、持久化 key 由 `StoreKitConfiguration` 注入；
/// - 「哪个商品对应什么档位」由 App 的商品表决定，Kit 层不解释；
/// - 购买面板、设置页等 UI 由各 App 的商店插件拥有。
///
/// ## 线程语义
///
/// 服务本身是 `actor`：StoreKit 的异步序列与商品请求天然适合 actor 隔离。
/// 需要主线程的回调通过参数传入的 `@MainActor` 闭包完成。
public actor StoreKitService {

    // MARK: - Configuration

    private let configuration: StoreKitConfiguration

    /// 权益变更回调（在主线程调用）。
    ///
    /// Kit 层不直接依赖内核，也不发 `NotificationCenter` 通知——把「权益变了」
    /// 这件事交给 App 决定如何广播（内核 Provider、Notification 或 SwiftUI 状态）。
    private let onEntitlementChanged: @MainActor @Sendable (StoreKitSubscriptionHolding) -> Void

    // MARK: - State

    /// 当前订阅持有情况（内存态）。
    private var cachedHolding: StoreKitSubscriptionHolding

    /// 交易监听任务。
    private var transactionListenerTask: Task<Void, Never>?

    /// 商品缓存：避免重复拉取。
    private var cachedProducts: [StoreKitProductInfo]?

    // MARK: - Init

    /// 创建服务。
    ///
    /// - Parameters:
    ///   - configuration: 商店配置（商品 ID 清单 + 持久化 key + 存储介质）。
    ///   - onEntitlementChanged: 权益变更回调，在主线程调用。
    public init(
        configuration: StoreKitConfiguration,
        onEntitlementChanged: @escaping @MainActor @Sendable (StoreKitSubscriptionHolding) -> Void
    ) {
        self.configuration = configuration
        self.onEntitlementChanged = onEntitlementChanged

        // 从缓存恢复到期时间，保留既有订阅持有结论。
        let expiration = configuration.entitlementStorage.loadExpiration()
        self.cachedHolding = StoreKitSubscriptionHolding(
            activeSubscriptionProductIDs: [],
            latestExpiration: expiration
        )
    }

    // MARK: - Public API

    /// 当前订阅持有情况。
    public var holding: StoreKitSubscriptionHolding {
        cachedHolding
    }

    /// 当前权益到期时间。
    public var expiration: Date? {
        cachedHolding.latestExpiration
    }

    /// 启动交易监听与初始权益校准。
    ///
    /// 重复调用不会启动第二个监听任务。
    public func bootstrap() async {
        startTransactionListener()
        await calibrateFromCurrentEntitlements()
    }

    /// 启动交易监听（幂等）。
    ///
    /// 监听会持续到 `stopTransactionListener()` 被调用。每笔交易先校准本地
    /// 权益再 `finish()`，符合 StoreKit 2 最佳实践。
    public func startTransactionListener() {
        guard transactionListenerTask == nil else { return }

        transactionListenerTask = Task { [weak self] in
            await self?.observeTransactionUpdates()
        }
    }

    /// 停止交易监听。
    public func stopTransactionListener() {
        transactionListenerTask?.cancel()
        transactionListenerTask = nil
    }

    /// 从当前权益校准本地缓存。
    ///
    /// 校准是「以商店为准」的权威同步：本地缓存可能因设备迁移、缓存过期
    /// 或退款而不准，启动时必须对齐。
    public func calibrateFromCurrentEntitlements() async {
        let transactions = await Self.currentEntitlementTransactions()
        guard !Task.isCancelled else { return }

        let aggregated = StoreKitSubscriptionAggregator.aggregate(transactions: transactions)
        await updateHolding(aggregated)
    }

    /// 拉取全部商品（按配置中的 ID 清单）。
    ///
    /// - Note: 并非从服务器枚举全部商品，而是以配置清单为准。
    public func fetchAllProducts() async throws -> [StoreKitProductInfo] {
        if let cachedProducts {
            return cachedProducts
        }

        let productIDs = configuration.productIDs
        guard !productIDs.isEmpty else {
            cachedProducts = []
            return []
        }

        let products: [Product]
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            throw StoreKitError.canNotGetProducts
        }

        let infos = products
            .map { StoreKitProductInfo(product: $0) }
            .sorted { $0.displayPrice < $1.displayPrice }

        cachedProducts = infos
        return infos
    }

    /// 订阅类商品。
    public func fetchSubscriptionProducts() async throws -> [StoreKitProductInfo] {
        try await fetchAllProducts().filter { $0.kind.isSubscription }
    }

    /// 发起购买。
    ///
    /// - Parameter productID: 商品 ID。
    /// - Returns: 购买成功返回交易凭据摘要；用户取消或待处理返回 `nil`。
    ///
    /// - Note: visionOS 上 StoreKit 不提供无场景的 `purchase(options:)`，
    ///   必须显式给出一个 `UIScene` 来承载购买面板。此重载在 visionOS 上
    ///   始终抛出 `StoreKitError.purchaseRequiresScene`，请改用
    ///   `purchase(productID:scene:)`。
    @discardableResult
    public func purchase(productID: String) async throws -> StoreKitTransactionSummary? {
        #if os(visionOS)
        throw StoreKitError.purchaseRequiresScene
        #else
        let products = try await Product.products(for: [productID])
        guard let product = products.first else {
            throw StoreKitError.productNotFound(productID)
        }

        let result = try await product.purchase()

        switch result {
        case let .success(verification):
            let transaction = try Self.checkVerified(verification)
            let summary = Self.summary(for: transaction)
            await applyTransaction(summary)
            return summary
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
        #endif
    }

    #if os(visionOS)
    /// 发起购买（visionOS：显式提供承载购买面板的场景）。
    ///
    /// visionOS 的 StoreKit 只有 `purchase(confirmIn scene:options:)` 这一种
    /// 购买入口，没有 macOS/iOS 上的无场景版本，因此调用方必须把当前的
    /// `UIScene` 交过来。
    ///
    /// - Parameters:
    ///   - productID: 商品 ID。
    ///   - scene: 承载购买面板的场景。
    /// - Returns: 购买成功返回交易凭据摘要；用户取消或待处理返回 `nil`。
    @discardableResult
    public func purchase(productID: String, scene: UIScene) async throws -> StoreKitTransactionSummary? {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else {
            throw StoreKitError.productNotFound(productID)
        }

        let result = try await product.purchase(confirmIn: scene)

        switch result {
        case let .success(verification):
            let transaction = try Self.checkVerified(verification)
            let summary = Self.summary(for: transaction)
            await applyTransaction(summary)
            return summary
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }
    #endif

    /// 恢复购买。
    ///
    /// 恢复走 `AppStore.sync()`：它会把商店端的凭据重新推给本机，
    /// 交易监听随后收到这些交易并更新权益。
    public func restorePurchases() async throws {
        try await AppStore.sync()
        await calibrateFromCurrentEntitlements()
    }

    /// 清除本地权益缓存（不改变商店端的真实权益）。
    ///
    /// 用于「重置本地状态」这类诊断操作。
    public func clearCachedEntitlement() async {
        configuration.entitlementStorage.clearExpiration()
        cachedHolding = .none
        await onEntitlementChanged(cachedHolding)
    }

    // MARK: - Verification

    /// 校验 StoreKit 的验证结果。
    ///
    /// 未验证的交易一律拒绝——这是付费链路的安全边界。
    public nonisolated static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.failedVerification
        case let .verified(safe):
            return safe
        }
    }

    // MARK: - Transaction Handling

    /// 监听交易更新直到取消。
    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            do {
                try Task.checkCancellation()
                let transaction = try Self.checkVerified(result)
                await applyTransaction(Self.summary(for: transaction))
                await transaction.finish()
            } catch is CancellationError {
                return
            } catch {
                Self.logger.error("\(Self.t)交易更新验证失败：\(error.localizedDescription)")
                continue
            }
        }
    }

    /// 应用一笔交易：更新有效订阅与到期时间。
    private func applyTransaction(_ summary: StoreKitTransactionSummary) async {
        guard summary.productType.isSubscription else {
            // 消耗品与一次性解锁不授予订阅权益。
            return
        }

        let expiration = StoreKitSubscriptionAggregator.effectiveExpiration(
            for: summary,
            now: Date()
        )

        let holding = StoreKitSubscriptionHolding(
            activeSubscriptionProductIDs: expiration == nil ? [] : [summary.productID],
            latestExpiration: expiration
        )

        await updateHolding(holding)
    }

    /// 写入权益并广播变更。
    private func updateHolding(_ holding: StoreKitSubscriptionHolding) async {
        cachedHolding = holding

        if let expiration = holding.latestExpiration {
            configuration.entitlementStorage.saveExpiration(expiration)
        } else {
            configuration.entitlementStorage.clearExpiration()
        }
        configuration.entitlementStorage.saveLastCheckedAt(Date())

        await onEntitlementChanged(holding)
    }

    // MARK: - Entitlement Reading

    /// 读取当前商店权益（`Transaction.currentEntitlements`）。
    ///
    /// 未验证的交易被跳过——不可信的凭据不参与权益判定。
    static func currentEntitlementTransactions() async -> [StoreKitTransactionSummary] {
        var transactions: [StoreKitTransactionSummary] = []

        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result else { continue }
            transactions.append(summary(for: transaction))
        }

        return transactions
    }

    /// 把 StoreKit 交易压缩成摘要。
    static func summary(for transaction: Transaction) -> StoreKitTransactionSummary {
        StoreKitTransactionSummary(
            productID: transaction.productID,
            productType: StoreKitProductType(transaction.productType),
            expirationDate: transaction.expirationDate,
            purchaseDate: transaction.purchaseDate
        )
    }
}

// MARK: - Logging

extension StoreKitService: SuperLog {
    public nonisolated static let emoji = "💰"

    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "store.storekit"
    )
}
