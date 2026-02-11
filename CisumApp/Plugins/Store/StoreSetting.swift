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
        MagicSettingSection(title: "Subscription Information") {
            // Current version
            MagicSettingRow(title: "Current Version", description: "Version you are using", icon: "star.fill", content: {
                HStack {
                    Text(tierDisplayName)
                        .font(.footnote)
                }
            })

            // Subscription status
            MagicSettingRow(title: "Subscription Status", description: statusDescription, icon: "info.circle", content: {
                HStack {
                    if purchaseInfo.isProOrHigher {
                        if purchaseInfo.isExpired {
                            Text("Expired")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        } else {
                            Text("Active")
                                .font(.footnote)
                                .foregroundStyle(.green)
                        }
                    } else {
                        Text("Free")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            })

            // Expiration date (if has subscription)
            if let expiresAt = purchaseInfo.expiresAt {
                MagicSettingRow(title: "Expiration Date", description: "Subscription expiration date", icon: "calendar", content: {
                    HStack {
                        Text(expiresAt.fullDateTime)
                            .font(.footnote)
                    }
                })
            }

            // Purchase entry
            MagicSettingRow(title: "In-App Purchase", description: "Subscribe to Pro to unlock all features", icon: "cart", content: {
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
            MagicSettingRow(title: "Restore Purchase", description: "Restore purchases made on other devices", icon: "arrow.clockwise", content: {
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
        purchaseInfo = StoreService.cachedPurchaseInfo()
        tierDisplayName = purchaseInfo.effectiveTier.displayName

        if purchaseInfo.isProOrHigher {
            if purchaseInfo.isExpired {
                statusDescription = "Subscription expired, please renew"
            } else {
                statusDescription = "Subscription active, enjoy full features"
            }
        } else {
            statusDescription = "Currently using free version"
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
