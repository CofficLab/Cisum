import MagicKit
import OSLog
import StoreKit
import SwiftUI

struct ProductCell: View, SuperLog {
    @State var isPurchased: Bool = false
    @State var errorTitle = ""
    @State var isShowingError: Bool = false
    @State var purchasing = false
    @State var btnHovered: Bool = false
    @State var status: Product.SubscriptionInfo.Status?
    @State var current: Product?

    let product: ProductDTO
    let purchasingEnabled: Bool
    let showStatus: Bool

    var isCurrent: Bool {
        if let current = current {
            return current.id == product.id
        }

        return false
    }

    nonisolated static let emoji = "🖥️"

    init(product: ProductDTO, purchasingEnabled: Bool = true, showStatus: Bool = false) {
        self.product = product
        self.purchasingEnabled = purchasingEnabled
        self.showStatus = showStatus
    }

    var body: some View {
        HStack(spacing: 16) {
            // 产品详情
            VStack(alignment: .leading, spacing: 8) {
                // 产品名称
                Text(product.displayName)
                    .font(.body)
                    .fontWeight(.medium)

                // 价格信息
                if let subscription = product.subscription {
                    HStack(spacing: 4) {
                        Text(product.displayPrice)
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("/")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatPeriodUnit(subscription.subscriptionPeriod))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(product.displayPrice)
                        .font(.title3)
                        .fontWeight(.bold)
                }

                // 试用期信息
                if let introOffer = product.subscription?.introductoryOffer {
                    HStack(spacing: 4) {
                        Image(systemName: "gift.fill")
                            .font(.caption2)
                        Text(formatIntroductoryOffer(introOffer))
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
            }

            Spacer()

            // 购买按钮
            if purchasingEnabled {
                buyButton
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadowSm()
        .alert(isPresented: $isShowingError, content: {
            Alert(title: Text(errorTitle), message: nil, dismissButton: .default(Text("好")))
        })
    }

    // MARK: 子视图

    /// 边框颜色
    private var borderColor: Color {
        if isCurrent || isPurchased {
            return .green.opacity(0.3)
        }
        return .clear
    }

    // MARK: 购买按钮的提示词

    @ViewBuilder
    func subscribeButton(_ subscription: SubscriptionInfoDTO) -> some View {
        VStack(spacing: 2) {
            // 主要价格信息
            Text(product.displayPrice + "/" + formatPeriodUnit(subscription.subscriptionPeriod))
                .foregroundColor(.white)
                .bold()
        }
    }

    // MARK: 格式化周期单位

    private func formatPeriodUnit(_ period: StoreSubscriptionPeriodDTO) -> String {
        let plural = 1 < period.value
        switch period.unit {
        case "day":
            return plural ? "\(period.value) 天" : "天"
        case "week":
            return plural ? "\(period.value) 周" : "周"
        case "month":
            return plural ? "\(period.value) 月" : "月"
        case "year":
            return plural ? "\(period.value) 年" : "年"
        default:
            return "period"
        }
    }

    // MARK: 格式化试用期信息

    private func formatIntroductoryOffer(_ offer: IntroductoryOfferDTO) -> String {
        let periodText: String
        let plural = offer.subscriptionPeriod.value > 1

        switch offer.subscriptionPeriod.unit {
        case "day":
            periodText = plural ? "\(offer.subscriptionPeriod.value) 天" : "天"
        case "week":
            periodText = plural ? "\(offer.subscriptionPeriod.value) 周" : "周"
        case "month":
            periodText = plural ? "\(offer.subscriptionPeriod.value) 月" : "月"
        case "year":
            periodText = plural ? "\(offer.subscriptionPeriod.value) 年" : "年"
        default:
            periodText = "period"
        }

        switch offer.paymentMode {
        case "FreeTrial":
            return "首\(periodText)免费"
        case "PayAsYouGo":
            return "首\(periodText)仅\(offer.displayPrice)"
        case "PayUpFront":
            return "首\(periodText)预付\(offer.displayPrice)"
        default:
            return "首\(periodText)优惠"
        }
    }

    // MARK: 购买按钮

    var buyButton: some View {
        HStack(spacing: 6) {
            if purchasing {
                ProgressView()
                    .scaleEffect(0.8)
                Text("处理中...")
            } else if isPurchased {
                Text(product.kind == .autoRenewable ? "已订阅" : "已购买")
            } else {
                Text(product.kind == .autoRenewable ? "订阅" : "购买")
            }
        }
        .fontWeight(.semibold)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .hoverScale(105)
        .roundedMedium()
        .shadowSm()
        .inButtonWithAction(buy)
        .disabled(purchasing || isPurchased)
        .opacity(isPurchased ? 0.6 : 1.0)
        .onAppear(perform: onAppear)
    }

    // MARK: 去购买

    func buy() {
        purchasing = true
        Task {
            do {
                os_log("\(self.t)🏬 点击了购买按钮")

                let result = try await StoreService.purchase(product)
                if result != nil {
                    withAnimation {
                        os_log("\(self.t)🏬 购买回调，更新购买状态为 true")
                        isPurchased = true
                    }
                } else {
                    os_log("\(self.t)购买回调，结果为空，表示取消了")
                }
            } catch StoreError.failedVerification {
                errorTitle = "App Store 验证失败"
                isShowingError = true
            } catch {
                errorTitle = error.localizedDescription
                isShowingError = true
            }

            purchasing = false
        }
    }
}

// MARK: Event Handler

extension ProductCell {
    func onAppear() {
        let verbose = false
        Task {
            // 检查购买状态
            let groups = try? await StoreService.fetchAllProducts()
            let purchasedLists = await StoreService.fetchPurchasedLists(
                cars: groups?.cars ?? [],
                subscriptions: groups?.subscriptions ?? [],
                nonRenewables: groups?.nonRenewables ?? []
            )

            switch product.kind {
            case .nonRenewable:
                isPurchased = purchasedLists.nonRenewables.contains { $0.id == product.id }
            case .nonConsumable:
                isPurchased = purchasedLists.cars.contains { $0.id == product.id }
            case .autoRenewable:
                isPurchased = purchasedLists.subscriptions.contains { $0.id == product.id }
            default:
                isPurchased = false
            }

            if verbose {
                os_log("\(self.t)OnAppear 检查购买状态 -> \(product.displayName) -> \(isPurchased)")
            }
        }
    }
}

// MARK: - Preview

#Preview("PurchaseView - All") {
    PurchaseView()
        .inRootView()
        .frame(height: 800)
}

#Preview("PurchaseView - Subscription Only") {
    PurchaseView(
        showSubscription: true,
        showOneTime: false,
        showNonRenewable: false,
        showConsumable: false)
        .inRootView()
        .frame(height: 800)
}

#Preview("Store Debug") {
    DebugView()
        .inRootView()
        .frame(width: 500, height: 700)
}

#Preview("Debug") {
    DebugView()
        .inRootView()
        .frame(height: 800)
}

#Preview("Buy") {
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

// MARK: - Supporting Views

/// 状态徽章组件
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }
}
