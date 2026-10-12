import CisumUIComponents
import MagicKit
import LumiUI
import StoreKit
import SwiftUI
import ProviderStore
import ProviderToast

struct DebugView: View, SuperLog {
    @Environment(\.toastProviding) private var toastProvider
    @State private var isLoading: Bool = false
    @State private var productGroups: ProductGroupsDTO?
    @State private var purchasedCars: [ProductDTO] = []
    @State private var purchasedSubscriptions: [ProductDTO] = []
    @State private var purchasedNonRenewables: [ProductDTO] = []
    @State private var subscriptionStatuses: [StoreSubscriptionStatusDTO] = []
    @State private var highestSubscriptionProduct: ProductDTO?
    @State private var highestSubscriptionStatus: StoreSubscriptionStatusDTO?
    @State private var subscriptionGroups: [SubscriptionGroupDTO] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Button(action: loadProducts) {
                    Text(isLoading ? "Loading…" : "Load Products")
                }
                .disabled(isLoading)

                Button(action: updateSubscriptionStatus) {
                    Text(isLoading ? "Loading…" : "Update Subscription Status")
                }
                .disabled(isLoading)

                Button(action: testFetchPurchased) {
                    Text(isLoading ? "Loading…" : "Test Purchase")
                }
                .disabled(isLoading)

                Button {
                    clear()
                } label: {
                    Text("Clear")
                }

                Spacer()
            }

            Divider()

            Spacer()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    GroupBox {
                        if let groups = self.productGroups {
                            productSection(groups: groups)
                        } else {
                            Text("Products not loaded yet")
                                .foregroundStyle(.secondary)
                        }
                    }

                    GroupBox {
                        purchasedSection()
                    }

                    GroupBox {
                        if let groups = self.productGroups {
                            subscriptionStatusSection(subscriptions: groups.subscriptions)
                        } else {
                            Text("Products not loaded yet")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Action

extension DebugView {
    func loadProducts() {
        isLoading = true
        productGroups = nil

        Task {
            do {
                let groups = try await StoreService.fetchAllProducts()
                setGroups(groups)
            } catch {
                toastProvider?.error(error)
            }

            self.isLoading = false
        }
    }

    func updateSubscriptionStatus() {
        isLoading = true

        Task {
            do {
                let result = try await StoreService.inspectSubscriptionStatus(self.className)
                setSubscriptionInspectResult(result)
            } catch {
                toastProvider?.error(error)
            }

            self.isLoading = false
            toastProvider?.info(String(localized: "Check Complete", bundle: .module))
        }
    }

    func clear() {
        productGroups = nil
        purchasedCars.removeAll()
        purchasedSubscriptions.removeAll()
        purchasedNonRenewables.removeAll()
        subscriptionStatuses.removeAll()
        highestSubscriptionProduct = nil
        highestSubscriptionStatus = nil
        subscriptionGroups.removeAll()
    }

    func testFetchPurchased() {
        isLoading = true

        Task {
            do {
                // 若尚未加载产品，先拉取
                let groups: ProductGroupsDTO
                if let existing = productGroups {
                    groups = existing
                } else {
                    groups = try await StoreService.fetchAllProducts()
                    setGroups(groups)
                }

                let result = await StoreService.fetchPurchasedLists(
                    cars: groups.cars,
                    subscriptions: groups.subscriptions,
                    nonRenewables: groups.nonRenewables
                )

                setPurchased(result)
                toastProvider?.info(String(localized: "Purchase list updated", bundle: .module))
            } catch {
                toastProvider?.error(error)
            }

            self.isLoading = false
        }
    }
}

// MARK: - Setter

extension DebugView {
    @MainActor
    func setGroups(_ newValue: ProductGroupsDTO) {
        productGroups = newValue
    }

    @MainActor
    func setPurchased(_ newValue: (
        cars: [ProductDTO],
        nonRenewables: [ProductDTO],
        subscriptions: [ProductDTO]
    )) {
        purchasedCars = newValue.cars
        purchasedNonRenewables = newValue.nonRenewables
        purchasedSubscriptions = newValue.subscriptions
    }

    @MainActor
    func setSubscriptionInspectResult(_ result: (
        subscriptions: [ProductDTO],
        statuses: [StoreSubscriptionStatusDTO],
        highestProduct: ProductDTO?,
        highestStatus: StoreSubscriptionStatusDTO?
    )) {
        subscriptionStatuses = result.statuses
        highestSubscriptionProduct = result.highestProduct
        highestSubscriptionStatus = result.highestStatus
    }

    @MainActor
    func setSubscriptionGroups(_ newValue: [SubscriptionGroupDTO]) {
        subscriptionGroups = newValue
    }
}

// MARK: - Private Helpers

extension DebugView {
    func groupSection(title: String, items: [ProductDTO]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(title) (\(items.count))")
                .font(.headline)
            if items.isEmpty {
                Text("Empty")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items, id: \.id) { p in
                    HStack {
                        Text(p.displayName)
                        Spacer()
                        if let s = p.subscription {
                            Text(s.groupDisplayName)
                        }
                        Spacer()
                        Text(p.displayPrice)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Divider()
        }
    }

    @ViewBuilder
    func purchasedSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Purchased")
                .font(.title3)
                .foregroundStyle(.brown)

            VStack(alignment: .leading, spacing: 4) {
                Text("Cars (\(purchasedCars.count))").font(.headline)
                if purchasedCars.isEmpty {
                    Text("Empty").foregroundStyle(.secondary)
                } else {
                    ForEach(purchasedCars, id: \.id) { p in
                        Text(p.displayName)
                    }
                }
                Divider()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Subscriptions (\(purchasedSubscriptions.count))").font(.headline)
                if purchasedSubscriptions.isEmpty {
                    Text("Empty").foregroundStyle(.secondary)
                } else {
                    ForEach(purchasedSubscriptions, id: \.id) { p in
                        Text(p.displayName)
                    }
                }
                Divider()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("NonRenewables (\(purchasedNonRenewables.count))").font(.headline)
                if purchasedNonRenewables.isEmpty {
                    Text("Empty").foregroundStyle(.secondary)
                } else {
                    ForEach(purchasedNonRenewables, id: \.id) { p in
                        Text(p.displayName)
                    }
                }
                Divider()
            }
        }
    }

    @ViewBuilder
    func productSection(groups: ProductGroupsDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Products")
                .font(.title3)
                .foregroundStyle(.red)

            groupSection(title: "Cars", items: groups.cars)
            subscriptionGroupsSection(subscriptionGroups: groups.subscriptionGroups)
            groupSection(title: "NonRenewables", items: groups.nonRenewables)
            groupSection(title: "Fuel", items: groups.fuel)
        }
    }

    @ViewBuilder
    func subscriptionGroupsSection(subscriptionGroups: [SubscriptionGroupDTO]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Subscription Groups (\(subscriptionGroups.count))")
                .font(.headline)

            if subscriptionGroups.isEmpty {
                Text("Empty")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(subscriptionGroups, id: \.id) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        // 订阅组标题
                        HStack {
                            Text(group.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("ID: \(group.id)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("(\(group.subscriptions.count) subscriptions)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)

                        // 订阅组下的订阅产品
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(group.subscriptions, id: \.id) { subscription in
                                HStack {
                                    Text("  • \(subscription.displayName)")
                                        .font(.caption)
                                    Spacer()
                                    Text(subscription.displayPrice)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, 8)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            Divider()
        }
    }

    @ViewBuilder
    func subscriptionStatusSection(subscriptions: [ProductDTO]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Subscription Status")
                .font(.title3)
                .foregroundStyle(.cyan)

            if let highest = highestSubscriptionProduct {
                HStack {
                    Text("Highest Product:")
                    Spacer()
                    Text(highest.displayName)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Highest Product: None").foregroundStyle(.secondary)
            }

            if let hs = highestSubscriptionStatus {
                HStack {
                    Text("Highest Status:")
                    Spacer()
                    Text("state=\(hs.state)")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Highest Status: None").foregroundStyle(.secondary)
            }

            Divider()

            Text("All Statuses (\(subscriptionStatuses.count))")
                .font(.headline)
            if subscriptionStatuses.isEmpty {
                Text("Empty").foregroundStyle(.secondary)
            } else {
                ForEach(Array(subscriptionStatuses.enumerated()), id: \.offset) { _, s in
                    HStack(alignment: .top) {
                        Text("state=")
                        Text("\(s.state)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let pid = s.currentProductID {
                            Text(pid).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
