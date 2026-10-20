import LumiUI
import SwiftUI

/// 空仓库引导 说明书 —— 章节式文档。
struct RepositoryGuidePluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Repository Guide", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Shows a short guide at the top of the player control area when the repository is empty.")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Empty Repository: the guide appears only when the repository is confirmed empty.", bundle: .module)),
                .init(String(localized: "Brand Header: the app icon and a welcome line take the place of the album cover.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "The guide is hidden once the repository has content.", bundle: .module)),
                .init(String(localized: "The guide is injected into the player control area via ControlViewProviding.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
