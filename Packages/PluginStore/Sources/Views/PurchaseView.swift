import CisumUIComponents
import MagicKit
import LumiUI
import OSLog
import StoreKit
import SwiftUI

struct PurchaseView: View, SuperLog {
    @LumiTheme private var appTheme
    nonisolated static let emoji = "🛒"
    nonisolated static let verbose = false

    var body: some View {
        SheetContainer {
            VStack {
                AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
                    VStack(spacing: 16) {
                        AppSheetIconHeader(systemImage: "giftcard.fill", title: nil as String?, tint: appTheme.primary)
                    // 版本对比
                        VersionComparisonView()

                    // 商品
                        ProductsSubscription(showHeader: false)
                    }
                }

                if let privacyURL = URL(string: "https://www.kuaiyizhi.cn/privacy"),
                   let licenseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                {
                    // Bottom links
                    HStack(spacing: 20) {
                        Link(destination: privacyURL) {
                            Label {
                                Text("Privacy Policy", bundle: .module)
                            } icon: {
                                Image(systemName: "hand.raised.fill")
                            }
                                .font(.footnote)
                        }

                        Divider()
                            .frame(height: 12)

                        Link(destination: licenseURL) {
                            Label {
                                Text("License Agreement", bundle: .module)
                            } icon: {
                                Image(systemName: "doc.text.fill")
                            }
                                .font(.footnote)
                        }
                    }
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                    .padding(.vertical, 16)
                    .infiniteWidth()
                }
            }
            .cisumPx2()
        }
    }
}
