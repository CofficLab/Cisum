import MagicKit
import OSLog
import StoreKit
import SwiftUI

struct PurchaseView: View, SuperLog {
    nonisolated static let emoji = "🛒"
    nonisolated static let verbose = false

    var body: some View {
        SheetContainer {
            VStack {
                VStack(spacing: 16) {
                    // 插画区域
                    VStack(spacing: 0) {
                        ZStack {
                            // 背景圆形装饰
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.blue.opacity(0.15),
                                            Color.purple.opacity(0.1),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)

                            // 主图标（购物/礼品）
                            Image(systemName: "giftcard.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .frame(height: 120)
                    }
                    .padding(.top, 8)

                    // 商品
                    ProductsSubscription(showHeader: false)
                }

                // 底部链接
                HStack(spacing: 20) {
                    Link(destination: URL(string: "https://www.kuaiyizhi.cn/privacy")!) {
                        Label("隐私政策", systemImage: "hand.raised.fill")
                            .font(.footnote)
                    }

                    Divider()
                        .frame(height: 12)

                    Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                        Label("许可协议", systemImage: "doc.text.fill")
                            .font(.footnote)
                    }
                }
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
                .padding(.vertical, 16)
                .infiniteWidth()
            }
            .px2()
            .background(.regularMaterial)
            .roundedMedium()
        }
    }
}

// MARK: - Preview

#Preview("PurchaseView") {
    PurchaseView()
        .inRootView()
        .frame(height: 800)
}

#Preview("Store Debug") {
    DebugView()
        .inRootView()
        .frame(width: 500, height: 700)
}

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
