import CisumUIComponents
import Foundation
import OSLog
import StoreKit
import SwiftUI
import ProviderStore

enum StorePurchaseInfoLoadPolicy {
    static func shouldApplyResult(currentGeneration: Int, resultGeneration: Int) -> Bool {
        resultGeneration == currentGeneration
    }
}

public struct StoreSetting: View, SuperLog, SuperEvent {
    public nonisolated static let emoji = "💰"
    nonisolated static let purchaseActionLabel = String(
        localized: "In-App Purchase",
        bundle: .module
    )
    nonisolated static let restorePurchaseActionLabel = String(
        localized: "Restore Purchase",
        bundle: .module
    )

    @ObservedObject private var viewModel: StoreViewModel

    init(viewModel: StoreViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 16) {
                AppSettingSection(title: String(localized: "Subscription Information", bundle: .module)) {
                    // Current version
                    AppSettingRow(
                        title: String(localized: "Current Version", bundle: .module),
                        description: String(localized: "Version you are using", bundle: .module),
                        icon: "star.fill"
                    ) {
                        Text(viewModel.tierDisplayName)
                            .font(.footnote)
                    }

                    // Subscription status
                    AppSettingRow(
                        title: String(localized: "Subscription Status", bundle: .module),
                        description: viewModel.statusDescription,
                        icon: "info.circle"
                    ) {
                        if viewModel.purchaseInfo.isProOrHigher {
                            if viewModel.purchaseInfo.isExpired {
                                Text("Expired", bundle: .module)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            } else {
                                Text("Active", bundle: .module)
                                    .font(.footnote)
                                    .foregroundStyle(.green)
                            }
                        } else {
                            Text("Free", bundle: .module)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Expiration date (if has subscription)
                    if let expiresAt = viewModel.purchaseInfo.expiresAt {
                        AppSettingRow(
                            title: String(localized: "Expiration Date", bundle: .module),
                            description: String(localized: "Subscription expiration date", bundle: .module),
                            icon: "calendar"
                        ) {
                            Text(expiresAt.fullDateTime)
                                .font(.footnote)
                        }
                    }

                    // Purchase entry
                    AppSettingRow(
                        title: String(localized: "In-App Purchase", bundle: .module),
                        description: String(localized: "Subscribe to Pro to unlock all features", bundle: .module),
                        icon: "cart"
                    ) {
                        Image.cisumAppStore
                            .frame(width: 28)
                            .frame(height: 28)
                            .background(.regularMaterial, in: .circle)
                            .cisumShadowSm()
                            .cisumHoverScale(105)
                            .cisumButton({
                                viewModel.showBuySheet = true
                            })
                            .accessibilityLabel(Self.purchaseActionLabel)
                            .help(Self.purchaseActionLabel)
                    }

                    // Restore purchase
                    AppSettingRow(
                        title: String(localized: "Restore Purchase", bundle: .module),
                        description: String(localized: "Restore purchases made on other devices", bundle: .module),
                        icon: "arrow.clockwise"
                    ) {
                        Image.cisumReset
                            .frame(width: 28)
                            .frame(height: 28)
                            .background(.regularMaterial, in: .circle)
                            .cisumShadowSm()
                            .cisumHoverScale(105)
                            .cisumButton({
                                viewModel.showRestoreSheet = true
                            })
                            .accessibilityLabel(Self.restorePurchaseActionLabel)
                            .help(Self.restorePurchaseActionLabel)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $viewModel.showBuySheet) {
            PurchaseView()
        }
        .sheet(isPresented: $viewModel.showRestoreSheet) {
            RestoreView()
        }
        .task {
            viewModel.updatePurchaseInfo()
        }
    }
}
