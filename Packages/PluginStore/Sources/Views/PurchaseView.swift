import MagicKit
import LumiUI
import OSLog
import StoreKit
import SwiftUI

struct PurchaseView: View, SuperLog {
    @LumiTheme private var appTheme
    nonisolated static let emoji = "🛒"
    nonisolated static let verbose = false

    /// 关闭动作（可选）。
    ///
    /// 默认走 SwiftUI 的 `dismiss()`——适用于真正的 sheet。全局引导里
    /// 购买面板是根视图上的 overlay，`dismiss()` 无物可关，调用方必须
    /// 显式传入自己的关闭动作。
    var onClose: (() -> Void)?

    var body: some View {
        SheetContainer(onClose: onClose) {
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

                // Bottom links
                StoreLegalLinks()
            }
            .padding(.horizontal, 8)
        }
    }
}
