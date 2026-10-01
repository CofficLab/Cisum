import CisumUIComponents
import LumiUI
import SwiftUI

/// 欢迎页 说明书 —— 章节式文档。
struct WelcomePluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Welcome Page", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Shows a welcome guide on first launch to help you get started")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Welcome Guide: shows welcome content on first launch.", bundle: .module)),
                .init(String(localized: "Quick Start: guides storage setup and basic operations.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Complete basic setup by following the guide on first launch.", bundle: .module)),
                .init(String(localized: "Skip or complete the welcome guide.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Shown only on first launch or after reset.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
