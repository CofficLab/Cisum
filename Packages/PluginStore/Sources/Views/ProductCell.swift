import CisumUIComponents
import MagicKit
import LumiUI
import OSLog
import StoreKit
import SwiftUI
import ProviderStore

struct ProductCell: View, SuperLog {
    @LumiTheme private var appTheme
    @State var isPurchased: Bool = false
    @State var errorTitle = ""
    @State var isShowingError: Bool = false
    @State var purchasing = false
    @State var btnHovered: Bool = false
    @State var status: Product.SubscriptionInfo.Status?
    @State var current: Product?

    let product: ProductDTO
    let initiallyPurchased: Bool
    let purchasingEnabled: Bool
    let showStatus: Bool

    var isCurrent: Bool {
        if let current = current {
            return current.id == product.id
        }

        return false
    }

    nonisolated static let emoji = "🖥️"
    nonisolated static let verbose = false

    init(product: ProductDTO, initiallyPurchased: Bool = false, purchasingEnabled: Bool = true, showStatus: Bool = false) {
        self.product = product
        self.initiallyPurchased = initiallyPurchased
        self.purchasingEnabled = purchasingEnabled
        self.showStatus = showStatus
        _isPurchased = State(initialValue: initiallyPurchased)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Product details.
            VStack(alignment: .leading, spacing: 8) {
                // Product name.
                Text(product.displayName)
                    .font(.body)
                    .fontWeight(.medium)

                // Price information.
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

                // Trial information.
                if let introOffer = product.subscription?.introductoryOffer {
                    HStack(spacing: 4) {
                        Image(systemName: "gift.fill")
                            .font(.caption2)
                            .accessibilityHidden(true)
                        Text(formatIntroductoryOffer(introOffer))
                            .font(.caption)
                    }
                    .foregroundStyle(appTheme.primary)
                }
            }

            Spacer()

            // Purchase button.
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
        .cisumShadowSm()
        .alert(isPresented: $isShowingError, content: {
            Alert(title: Text(LocalizedStringKey(errorTitle), bundle: .module), message: nil, dismissButton: .default(Text("OK", bundle: .module)))
        })
        .onChange(of: initiallyPurchased) { _, newValue in
            isPurchased = newValue
        }
    }

    // MARK: Subviews

    /// Border color.
    private var borderColor: Color {
        if isCurrent || isPurchased {
            return appTheme.success.opacity(0.3)
        }
        return .clear
    }

    // MARK: Purchase Button Text

    @ViewBuilder
    func subscribeButton(_ subscription: SubscriptionInfoDTO) -> some View {
        VStack(spacing: 2) {
            // Primary price information.
            Text(product.displayPrice + "/" + formatPeriodUnit(subscription.subscriptionPeriod))
                .foregroundColor(.white)
                .bold()
        }
    }

    // MARK: Format Period Unit

    private func formatPeriodUnit(_ period: StoreSubscriptionPeriodDTO) -> String {
        let plural = 1 < period.value
        switch period.unit {
        case "day":
            return plural ? String(localized: "\(period.value) days", bundle: .module) : String(localized: "day", bundle: .module)
        case "week":
            return plural ? String(localized: "\(period.value) weeks", bundle: .module) : String(localized: "week", bundle: .module)
        case "month":
            return plural ? String(localized: "\(period.value) months", bundle: .module) : String(localized: "month", bundle: .module)
        case "year":
            return plural ? String(localized: "\(period.value) years", bundle: .module) : String(localized: "year", bundle: .module)
        default:
            return String(localized: "period", bundle: .module)
        }
    }

    // MARK: Format Trial Information

    private func formatIntroductoryOffer(_ offer: IntroductoryOfferDTO) -> String {
        let periodText: String
        let plural = offer.subscriptionPeriod.value > 1

        switch offer.subscriptionPeriod.unit {
        case "day":
            periodText = plural ? String(localized: "\(offer.subscriptionPeriod.value) days", bundle: .module) : String(localized: "day", bundle: .module)
        case "week":
            periodText = plural ? String(localized: "\(offer.subscriptionPeriod.value) weeks", bundle: .module) : String(localized: "week", bundle: .module)
        case "month":
            periodText = plural ? String(localized: "\(offer.subscriptionPeriod.value) months", bundle: .module) : String(localized: "month", bundle: .module)
        case "year":
            periodText = plural ? String(localized: "\(offer.subscriptionPeriod.value) years", bundle: .module) : String(localized: "year", bundle: .module)
        default:
            periodText = String(localized: "period", bundle: .module)
        }

        switch offer.paymentMode {
        case "FreeTrial":
            return String(localized: "Free for \(periodText)", bundle: .module)
        case "PayAsYouGo":
            return String(localized: "\(offer.displayPrice) for first \(periodText)", bundle: .module)
        case "PayUpFront":
            return String(localized: "Pay \(offer.displayPrice) for first \(periodText)", bundle: .module)
        default:
            return String(localized: "Special offer for \(periodText)", bundle: .module)
        }
    }

    // MARK: Purchase Button

    var buyButton: some View {
        HStack(spacing: 6) {
            if purchasing {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Processing...", bundle: .module)
            } else if isPurchased {
                Text(product.kind == .autoRenewable ? "Subscribed" : "Purchased", bundle: .module)
            } else {
                Text(product.kind == .autoRenewable ? "Subscribe" : "Purchase", bundle: .module)
            }
        }
        .fontWeight(.semibold)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(appTheme.primary.opacity(0.12))
        .foregroundStyle(appTheme.primary)
        .cisumHoverScale(105)
        .cisumRoundedMedium()
        .cisumShadowSm()
        .cisumButton(buy)
        .disabled(purchasing || isPurchased)
        .opacity(isPurchased ? 0.6 : 1.0)
    }

    // MARK: Purchase

    func buy() {
        purchasing = true
        Task {
            do {
                if Self.verbose {
                    os_log("\(self.t)🏬 Purchase button tapped")
                }

                let result = try await StoreService.purchase(product)
                if result != nil {
                    withAnimation {
                        if Self.verbose {
                            os_log("\(self.t)🏬 Purchase callback received, setting purchased state to true")
                        }
                        isPurchased = true
                    }
                } else {
                    if Self.verbose {
                        os_log("\(self.t)Purchase callback returned nil, treating as canceled")
                    }
                }
            } catch StoreError.failedVerification {
                errorTitle = "App Store verification failed"
                isShowingError = true
            } catch {
                errorTitle = error.localizedDescription
                isShowingError = true
            }

            purchasing = false
        }
    }
}
