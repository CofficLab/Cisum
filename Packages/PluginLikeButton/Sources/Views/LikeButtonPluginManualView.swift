import CisumUIComponents
import LumiUI
import SwiftUI

/// 喜欢按钮 说明书 —— 章节式文档。
struct LikeButtonPluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Like Button", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Provides a unified Favorite button in the toolbar")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Toolbar Button: quickly likes from the toolbar.", bundle: .module)),
                .init(String(localized: "State Sync: stays in sync with each media's like state.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Click the heart button in the toolbar.", bundle: .module)),
                .init(String(localized: "Toggles the like state of the current media.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Currently disabled; you can enable it in the Plugin Manager.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
