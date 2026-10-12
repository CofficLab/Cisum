import CisumUIComponents
import MagicKit
import LumiUI
import OSLog
import StoreKit
import SwiftUI
import ProviderStore

enum StoreProductListPresentation {
    enum State: Equatable {
        case loading
        case error
        case empty
        case content
    }

    static func state(isRefreshing: Bool, hasGroups: Bool, hasError: Bool) -> State {
        if isRefreshing, !hasGroups {
            return .loading
        }

        if hasError, !hasGroups {
            return .error
        }

        if !hasGroups {
            return .empty
        }

        return .content
    }
}

enum StoreProductLoadPolicy {
    static func shouldApplyResult(currentGeneration: Int, resultGeneration: Int) -> Bool {
        resultGeneration == currentGeneration
    }
}

enum StoreSubscriptionCountTextPolicy {
    static func shouldUseSingular(_ count: Int) -> Bool {
        count == 1
    }
}

struct ProductsSubscription: View, SuperEvent, SuperLog, SuperThread {
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @State private var subscriptionGroups: [SubscriptionGroupDTO] = []
    @State private var purchasedProductIDs = Set<String>()
    @State private var refreshing = false
    @State private var error: Error? = nil
    @State private var loadGeneration = 0

    nonisolated static let emoji = "🖥️"
    nonisolated static var verbose: Bool { false }

    /// Whether to show the header.
    var showHeader: Bool = true

    init(showHeader: Bool = true) {
        self.showHeader = showHeader
    }

    var body: some View {
        Group {
            switch StoreProductListPresentation.state(
                isRefreshing: refreshing,
                hasGroups: !subscriptionGroups.isEmpty,
                hasError: error != nil
            ) {
            case .loading:
                loadingStateView
            case .error:
                errorStateView
            case .empty:
                emptyStateView
            case .content:
                LazyVStack(spacing: 20) {
                    ForEach(subscriptionGroups, id: \.id) { group in
                        VStack(alignment: .leading, spacing: 16) {
                            // Subscription group header.
                            if showHeader {
                                HStack(alignment: .center, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(group.name)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .cisumIf(group.name.isNotEmpty)

                                        Group {
                                            if Self.shouldUseSingularSubscriptionCount(group.subscriptions.count) {
                                                Text("\(group.subscriptions.count) subscription option", bundle: .module)
                                            } else {
                                                Text("\(group.subscriptions.count) subscription options", bundle: .module)
                                            }
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    // Subscription group ID label.
                                    Text("ID: \(group.id)")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            // Subscription product list.
                            VStack(spacing: 12) {
                                ForEach(group.subscriptions, id: \.id) { subscription in
                                    ProductCell(
                                        product: subscription,
                                        initiallyPurchased: purchasedProductIDs.contains(subscription.id)
                                    )
                                }
                            }
                        }
                    }
                }
                .cisumScrollView()
            }
        }
        .onAppear(perform: onAppear)
        .onRestored(perform: onRestore)
    }

    // MARK: - Subviews

    /// Empty state view.
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart.circle")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Text("No subscription options available", bundle: .module)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingStateView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading subscription options...", bundle: .module)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorStateView: some View {
        VStack(spacing: 16) {
            AppStatusBanner(
                kind: .error,
                title: String(localized: "Cannot load subscription options", bundle: .module),
                message: error?.localizedDescription ?? String(localized: "Please check your network and try again.", bundle: .module)
            )

            AppButton(
                String(localized: "Try Again", bundle: .module),
                systemImage: "arrow.clockwise",
                style: .primary,
                fillsWidth: true
            ) {
                getProducts("Retry after load failure")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
    }

    // MARK: Fetch Available Subscriptions

    private func getProducts(_ reason: String) {
        if Self.verbose {
            os_log("\(self.t)🚀 (\(reason)) GetProducts")
        }

        refreshing = true
        loadGeneration += 1
        let generation = loadGeneration

        Task {
            do {
                let groups = try await StoreService.fetchAllProducts()
                let purchasedLists = await StoreService.fetchPurchasedLists(
                    cars: groups.cars,
                    subscriptions: groups.subscriptions,
                    nonRenewables: groups.nonRenewables
                )
                let purchasedIDs = Set(
                    (purchasedLists.cars + purchasedLists.subscriptions + purchasedLists.nonRenewables).map(\.id)
                )
                await MainActor.run {
                    guard StoreProductLoadPolicy.shouldApplyResult(
                        currentGeneration: self.loadGeneration,
                        resultGeneration: generation
                    ) else { return }

                    self.subscriptionGroups = groups.subscriptionGroups
                    self.purchasedProductIDs = purchasedIDs
                    self.error = nil
                    self.refreshing = false
                }
            } catch {
                await MainActor.run {
                    guard StoreProductLoadPolicy.shouldApplyResult(
                        currentGeneration: self.loadGeneration,
                        resultGeneration: generation
                    ) else { return }

                    self.error = error
                    self.refreshing = false
                }
            }
        }
    }
}

// MARK: Event Handler

extension ProductsSubscription {
    nonisolated static func shouldUseSingularSubscriptionCount(_ count: Int) -> Bool {
        StoreSubscriptionCountTextPolicy.shouldUseSingular(count)
    }

    func onAppear() {
        getProducts("AllSubscription OnAppear")
    }

    func onRestore(_ notification: Notification) {
        getProducts("Restore purchases")
    }
}
