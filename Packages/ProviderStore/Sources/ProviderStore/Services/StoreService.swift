import Foundation
import CisumUIComponents
import OSLog
import StoreKit
import SwiftUI

// MARK: - Typealias

public typealias Transaction = StoreKit.Transaction
public typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
public typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState
public typealias PaymentMode = StoreKit.Product.SubscriptionOffer.PaymentMode

public enum StoreService: SuperLog {
    public static let emoji = "💰"
    static let verbose = false

    struct SubscriptionStatusSnapshot: Equatable, Sendable {
        let state: RenewalState.RawValue
        let currentProductID: String?
    }

    // MARK: - Bootstrap

    /// Starts listening for transaction updates. Call this when the app starts.
    public static func bootstrap() {
        startTransactionListener()
        Task { await StoreState.calibrateFromCurrentEntitlements() }
    }

    // MARK: - Transaction Updates

    /// Starts listening for transaction updates. Call this when the app starts.
    /// This follows StoreKit 2 best practice so no transactions are missed.
    public static func startTransactionListener() {
        Task {
            guard await StoreTransactionListenerState.shared.markStartedIfNeeded() else { return }

            if verbose {
                os_log("\(self.t)👀 Starting transaction update listener")
            }
            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result)
                    if verbose {
                        os_log("\(self.t)📱 Received transaction update: \(transaction.productID)")
                    }

                    // Handle the transaction update.
                    await handleTransactionUpdate(transaction)

                    // Finish the transaction.
                    await transaction.finish()
                } catch {
                    if verbose {
                        os_log(.error, "\(self.t)❌ Transaction update verification failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    static func shouldStartTransactionListener(isStarted: Bool) -> Bool {
        !isStarted
    }

    /// Handles a transaction update.
    private static func handleTransactionUpdate(_ transaction: Transaction) async {
        if verbose {
            os_log("\(self.t)✅ Handling transaction update: \(transaction.productID)")
        }
        let tier = tier(for: transaction.productID)
        let expires: Date? = transaction.expirationDate
        await MainActor.run {
            StoreState.update(entitlement: PurchaseInfo(tier: tier, expiresAt: expires))
            postTransactionUpdated(productID: transaction.productID)
        }
    }

    // MARK: - Store State Updates

    /// Updates StoreState after a successful purchase.
    private static func updateStoreStateAfterPurchase(_ transaction: Transaction) async {
        let tier = tier(for: transaction.productID)
        let expiresAt = transaction.expirationDate

        if verbose {
            os_log("\(self.t)🔄 Updating StoreState")
        }

        await MainActor.run {
            StoreState.update(entitlement: PurchaseInfo(tier: tier, expiresAt: expiresAt))
            postTransactionUpdated(productID: transaction.productID)
        }
    }

    @MainActor
    static func postTransactionUpdated(productID: String) {
        NotificationCenter.default.post(name: .storeTransactionUpdated, object: productID)
    }

    // MARK: - Public State Accessors

    /// Gets current purchase information and triggers one cloud entitlement sync.
    public static func getPurchaseInfo() async -> PurchaseInfo {
        await StoreState.calibrateFromCurrentEntitlements()
        return cachedPurchaseInfo()
    }

    public static func cachedPurchaseInfo() -> PurchaseInfo {
        return StoreState.cachedPurchaseInfo()
    }

    public static func tierCached() -> SubscriptionTier {
        cachedPurchaseInfo().effectiveTier
    }

    /// Reads the expiration date from the local cache.
    public static func expiresAtCached() -> Date? {
        cachedPurchaseInfo().expiresAt
    }

    // MARK: - Data Sources

    /// All product IDs.
    private static func allProductIds() -> [String] {
        StoreConfig.allProductIds
    }

    // MARK: - Product Fetching

    // Product list fetching is cached.
    // After fetching online, the list can still be available briefly while offline.
    // Observed cases:
    //  Offline: error.
    //  Online fetch returns two products, then offline still returns two products.
    //  Online fetch returns two products, then offline returns two products, then later returns zero without an error.
    private static func requestProducts(productIds: some Sequence<String>) async throws -> ProductGroupsDTO {
        let idsArray = Array(productIds)
        let storeProducts = try await Product.products(for: idsArray)
        return ProductGroupsDTO(products: storeProducts)
    }

    /// Fetches all configured products by reading the product ID list, then requesting details and grouping them.
    ///
    /// - Note: This does not enumerate all products from the server. It uses the locally or remotely configured product ID list.
    /// - Returns: `StoreProductGroupsDTO` containing cars, subscriptions, nonRenewables, fuel, and other groups.
    public static func fetchAllProducts() async throws -> ProductGroupsDTO {
        try await Self.requestProducts(productIds: Self.allProductIds())
    }

    /// Fetches all subscription groups by grouping subscription products by subscription group ID.
    ///
    /// - Returns: `[SubscriptionGroupDTO]`.
    /// - Note: Depends on `fetchAllProducts()`, so results are constrained by the product ID list.
    public static func fetchAllSubscriptionGroups() async throws -> [SubscriptionGroupDTO] {
        let products = try await fetchAllProducts()
        return products.subscriptionGroups
    }

    // MARK: - Purchased Fetching

    /// Filters and categorizes purchased products from the current account's `Transaction.currentEntitlements`.
    ///
    /// - Important: This method does not fetch products. First fetch complete product groups with
    ///   `requestProducts(productIds:)`, then pass each group here for filtering and matching.
    ///
    /// - Parameters:
    ///   - cars: Already fetched non-consumable products, such as one-time unlocks.
    ///   - subscriptions: Already fetched auto-renewable subscription products.
    ///   - nonRenewables: Already fetched non-renewing subscription products.
    ///
    /// - Returns: Purchased product lists filtered by transactions:
    ///   `(cars: [StoreProductDTO], nonRenewables: [StoreProductDTO], subscriptions: [StoreProductDTO])`.
    ///
    /// - Note:
    ///   - Unverified transactions are ignored after `checkVerified` validation.
    ///   - Non-renewing subscriptions count only when `productID == "nonRenewing.standard"` and the purchase is within one year.
    ///   - This method is async because `Transaction.currentEntitlements` is an async sequence.
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

    public static func tier(for productId: String) -> SubscriptionTier {
        StoreConfig.tier(for: productId)
    }

    public static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case let .verified(safe):
            return safe
        }
    }

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

    // MARK: - Pay

    private static func purchase(_ product: Product) async throws -> Transaction? {
        if verbose {
            os_log("\(self.t)🏬 Starting purchase")
        }

        #if os(visionOS)
            return nil
        #else
            // Begin purchasing the `Product` the user selects.
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

    public static func purchase(_ product: ProductDTO) async throws -> Transaction? {
        let products = try await Product.products(for: [product.id])
        guard let storekitProduct = products.first else { return nil }
        return try await purchase(storekitProduct)
    }

    /// Inspects subscription group status and returns useful data: subscription products, status details, and highest-tier entries.
    ///
    /// - Parameters:
    ///   - reason: Call reason used for diagnostics.
    ///   - verbose: Whether detailed logs should be emitted.
    /// - Returns: Tuple `(subscriptions, statuses, highestProduct, highestStatus)`:
    ///   - `subscriptions`: Current available subscription products in the same group.
    ///   - `statuses`: Status array from the subscription group, mapped to `StoreSubscriptionStatusDTO`.
    ///   - `highestProduct`: Product for the current highest tier, when it can be determined.
    ///   - `highestStatus`: Status for the current highest tier, when it can be determined.
    public static func inspectSubscriptionStatus(_ reason: String, verbose: Bool = false) async throws -> (
        subscriptions: [ProductDTO],
        statuses: [StoreSubscriptionStatusDTO],
        highestProduct: ProductDTO?,
        highestStatus: StoreSubscriptionStatusDTO?
    ) {
        if verbose {
            os_log("\(self.t)Checking subscription status, reason: \(reason)")
        }

        // Multiple subscription groups can exist:
        //  1. Pro subscription plan
        //    1.1 Yearly, ID: com.coffic.pro.year
        //    1.2 Monthly, ID: com.coffic.pro.month
        //  2. Ultimate subscription plan
        //    2.1 Yearly, ID: com.coffic.ultmate.year
        //    2.2 Monthly, ID: com.coffic.ultmate.month

        let products = try await Self.requestProducts(productIds: StoreService.allProductIds())

        // Get the current subscribable product list, such as:
        /// - com.coffic.pro.year
        /// - com.coffic.pro.month
        /// - com.coffic.ultmate.year
        /// - com.coffic.ultmate.month
        let subscriptions = products.subscriptions

        if subscriptions.isEmpty {
            return (subscriptions: [], statuses: [], highestProduct: nil, highestStatus: nil)
        }

        // This app has only one subscription group, so products in the subscriptions
        // array all belong to the same group. The statuses that
        // `product.subscription.status` returns apply to the entire subscription group.
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
        var highestTier: SubscriptionTier = .none

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

            let tier = tier(for: productID)
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

private actor StoreTransactionListenerState {
    static let shared = StoreTransactionListenerState()

    private var isStarted = false

    func markStartedIfNeeded() -> Bool {
        guard !isStarted else { return false }
        isStarted = true
        return true
    }
}
