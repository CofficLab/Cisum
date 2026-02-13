import Foundation
import MagicAlert
import MagicKit
import OSLog
import StoreKit
import SwiftUI

struct StoreSetting: View, SuperLog, SuperEvent {
    nonisolated static let emoji = "💰"

    @State private var showBuySheet = false
    @State private var showRestoreSheet = false
    @State private var purchaseInfo: PurchaseInfo = .none
    @State private var tierDisplayName: String = "Free"
    @State private var statusDescription: String = "Currently using free version"


    var body: some View {
        MagicSettingSection(title: String(localized: "Subscription Information", table: "Store")) {
            // Current version
            MagicSettingRow(title: String(localized: "Current Version", table: "Store"), description: String(localized: "Version you are using", table: "Store"), icon: "star.fill", content: {
                HStack {
                    Text(tierDisplayName)
                        .font(.footnote)
                }
            })

            // Subscription status
            MagicSettingRow(title: String(localized: "Subscription Status", table: "Store"), description: statusDescription, icon: "info.circle", content: {
                HStack {
                    if purchaseInfo.isProOrHigher {
                        if purchaseInfo.isExpired {
                            Text("Expired", tableName: "Store")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        } else {
                            Text("Active", tableName: "Store")
                                .font(.footnote)
                                .foregroundStyle(.green)
                        }
                    } else {
                        Text("Free", tableName: "Store")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            })

            // Expiration date (if has subscription)
            if let expiresAt = purchaseInfo.expiresAt {
                MagicSettingRow(title: String(localized: "Expiration Date", table: "Store"), description: String(localized: "Subscription expiration date", table: "Store"), icon: "calendar", content: {
                    HStack {
                        Text(expiresAt.fullDateTime)
                            .font(.footnote)
                    }
                })
            }

            // Purchase entry
            MagicSettingRow(title: String(localized: "In-App Purchase", table: "Store"), description: String(localized: "Subscribe to Pro to unlock all features", table: "Store"), icon: "cart", content: {
                Image.appStore
                    .frame(width: 28)
                    .frame(height: 28)
                    .background(.regularMaterial, in: .circle)
                    .shadowSm()
                    .hoverScale(105)
                    .inButtonWithAction({
                        showBuySheet = true
                    })
            })

            // Restore purchase
            MagicSettingRow(title: String(localized: "Restore Purchase", table: "Store"), description: String(localized: "Restore purchases made on other devices", table: "Store"), icon: "arrow.clockwise", content: {
                Image.reset
                    .frame(width: 28)
                    .frame(height: 28)
                    .background(.regularMaterial, in: .circle)
                    .shadowSm()
                    .hoverScale(105)
                    .inButtonWithAction({
                        showRestoreSheet = true
                    })
            })
        }
        .sheet(isPresented: $showBuySheet) {
            PurchaseView()
        }
        .sheet(isPresented: $showRestoreSheet) {
            RestoreView()
        }
        .task {
            self.updatePurchaseInfo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .storeTransactionUpdated)) { _ in
            self.updatePurchaseInfo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .Restored)) { _ in
            self.updatePurchaseInfo()
        }
    }
}

// MARK: - Actions

extension StoreSetting {
    private func updatePurchaseInfo() {
        Task {
            let info = await StoreService.getPurchaseInfo()
            await MainActor.run {
                self.purchaseInfo = info
                self.tierDisplayName = StoreService.tierCached().displayName

                if info.isProOrHigher {
                    if info.isExpired {
                        self.statusDescription = String(localized: "Subscription has expired, please renew to continue using Pro features", table: "Store")
                    } else {
                        self.statusDescription = String(localized: "Subscription is active, thank you for your support", table: "Store")
                    }
                } else {
                    self.statusDescription = String(localized: "Currently using free version", table: "Store")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Store Settings") {
    StoreSetting()
        .inRootView()
        .frame(width: 400)
        .frame(height: 800)
}

#Preview("Purchase") {
    PurchaseView()
        .inRootView()
        .frame(height: 800)
}

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
