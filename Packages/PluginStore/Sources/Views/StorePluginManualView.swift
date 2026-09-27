import CisumUIComponents
import LumiUI
import SwiftUI

/// 商店 说明书 —— 章节式文档。
struct StorePluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Store", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Browse and purchase Cisum's premium services and extensions")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Product Browsing: browse purchasable premium services.", bundle: .module)),
                .init(String(localized: "Restore Purchases: restores your past purchases.", bundle: .module)),
                .init(String(localized: "Purchase: completes the in-app purchase.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Browse products in the store.", bundle: .module)),
                .init(String(localized: "Select a product and complete the purchase.", bundle: .module)),
                .init(String(localized: "After switching devices, use Restore Purchases to recover your benefits.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Purchases are completed via App Store in-app purchase.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
