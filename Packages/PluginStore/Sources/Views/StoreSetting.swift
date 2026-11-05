import MagicKit
import LumiUI
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
                }

                // 应用内购买：版本对比 + 商品列表直接铺在设置页里，
                // 不再需要点按钮弹层。
                AppSettingSection(title: String(localized: "In-App Purchase", bundle: .module)) {
                    VersionComparisonView()
                        .padding(.vertical, 4)

                    ProductsSubscription(showHeader: false, embedsScrollView: false)

                    // 隐私政策与许可协议：购买前必须能读到，弹层里也有一份。
                    StoreLegalLinks()
                }

                // Restore purchase
                AppSettingSection {
                    AppSettingRow(
                        title: String(localized: "Restore Purchase", bundle: .module),
                        description: String(localized: "Restore purchases made on other devices", bundle: .module),
                        icon: "arrow.clockwise"
                    ) {
                        Image.appReset
                            .frame(width: 28)
                            .frame(height: 28)
                            .background(.regularMaterial, in: .circle)
                            .shadowSm()
                            .appHoverScale(1.05)
                            .appPlainButton({
                                viewModel.showRestoreSheet = true
                            })
                            .accessibilityLabel(Self.restorePurchaseActionLabel)
                            .help(Self.restorePurchaseActionLabel)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $viewModel.showRestoreSheet) {
            RestoreView()
        }
        .task {
            viewModel.updatePurchaseInfo()
        }
    }
}
