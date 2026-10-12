import CisumUIComponents
import LumiUI
import SwiftUI

/// 商店 关于视图 —— Landing 落地页。
struct StorePluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "cart",
                accent: theme.primary,
                tagline: String(localized: "Browse and purchase Cisum's premium services and extensions", bundle: .module),
                chips: [String(localized: "Store", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "cart", tint: theme.primary, title: String(localized: "Product Browsing", bundle: .module), description: String(localized: "Browses purchasable premium services.", bundle: .module)),
                .init(icon: "checkmark.seal", tint: theme.info, title: String(localized: "Restore Purchases", bundle: .module), description: String(localized: "Restores your past purchases.", bundle: .module)),
                .init(icon: "creditcard", tint: theme.success, title: String(localized: "Purchase", bundle: .module), description: String(localized: "Completes the in-app purchase.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
