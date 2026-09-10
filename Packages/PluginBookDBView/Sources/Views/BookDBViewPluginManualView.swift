import CisumUIComponents
import SwiftUI

/// 有声书数据库 说明书 —— 章节式文档。
struct BookDBViewPluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Audiobook Database", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Browse and organize audiobook files in a database view")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Database: centrally manages the database records of audiobook files.", bundle: .module)),
                .init(String(localized: "Sorting: browses sorted by multiple dimensions.", bundle: .module)),
                .init(String(localized: "Clean Up: removes invalid or duplicate records.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Opens the audiobook database view.", bundle: .module)),
                .init(String(localized: "Filters or sorts audiobook records as needed.", bundle: .module)),
                .init(String(localized: "Removes records that are no longer needed.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "The database shares the storage location with the audiobook library.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
