import CisumUIComponents
import LumiUI
import SwiftUI

/// 有声书库 说明书 —— 章节式文档。
struct BookPluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Audiobook Library", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Manage, browse, and play local audiobooks")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Audiobook Library: manages local audiobook files.", bundle: .module)),
                .init(String(localized: "Search: quickly find audiobooks by name.", bundle: .module)),
                .init(String(localized: "Play: starts playback from the audiobook library.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Opens the audiobook scene to browse all audiobooks.", bundle: .module)),
                .init(String(localized: "Use the search field to filter audiobooks by name.", bundle: .module)),
                .init(String(localized: "Click any audiobook to start playing.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "The audiobook library depends on a local storage location.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
