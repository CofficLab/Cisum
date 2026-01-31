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
    @State private var tierDisplayName: String = "免费版"
    @State private var statusDescription: String = "当前使用免费版本"

    @EnvironmentObject var m: MagicMessageProvider

    var body: some View {
        MagicSettingSection(title: "订阅信息") {
            // 当前版本
            MagicSettingRow(title: "当前版本", description: "您正在使用的版本", icon: "star.fill", content: {
                HStack {
                    Text(tierDisplayName)
                        .font(.footnote)
                }
            })

            // 订阅状态
            MagicSettingRow(title: "订阅状态", description: statusDescription, icon: "info.circle", content: {
                HStack {
                    if purchaseInfo.isProOrHigher {
                        if purchaseInfo.isExpired {
                            Text("已过期")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        } else {
                            Text("有效")
                                .font(.footnote)
                                .foregroundStyle(.green)
                        }
                    } else {
                        Text("免费版")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            })

            // 到期时间（如果有订阅）
            if let expiresAt = purchaseInfo.expiresAt {
                MagicSettingRow(title: "到期时间", description: "订阅到期日期", icon: "calendar", content: {
                    HStack {
                        Text(expiresAt.fullDateTime)
                            .font(.footnote)
                    }
                })
            }

            // 购买入口
            MagicSettingRow(title: "应用内购买", description: "订阅专业版，解锁所有功能", icon: "cart", content: {
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

            // 恢复购买
            MagicSettingRow(title: "恢复购买", description: "在其他设备上购买后可在此恢复", icon: "arrow.clockwise", content: {
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
            PurchaseView(showSubscription: true)
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
                statusDescription = "订阅已过期，请续费"
            } else {
                statusDescription = "订阅有效，享受完整功能"
            }
        } else {
            statusDescription = "当前使用免费版本"
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

#if os(macOS)
    #Preview("App - Large") {
        ContentView()
            .inRootView()
            .frame(width: 600, height: 1000)
    }

    #Preview("App - Small") {
        ContentView()
            .inRootView()
            .frame(width: 500, height: 800)
    }
#endif

#if os(iOS)
    #Preview("iPhone") {
        ContentView()
            .inRootView()
    }
#endif
