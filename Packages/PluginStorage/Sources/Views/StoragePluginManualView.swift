import CisumUIComponents
import LumiUI
import SwiftUI

/// 存储管理 说明书 —— 章节式文档。
struct StoragePluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Storage Management", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Manage app data storage location, migration, and file browsing")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Storage Location: configures the data storage directory.", bundle: .module)),
                .init(String(localized: "Migrate: moves data between storage locations.", bundle: .module)),
                .init(String(localized: "File Browser: browses the app's data files.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Configure the storage location in Settings.", bundle: .module)),
                .init(String(localized: "Performs data migration when needed.", bundle: .module)),
                .init(String(localized: "Browses the app's data files.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Before migrating, make sure the target location has enough space.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
