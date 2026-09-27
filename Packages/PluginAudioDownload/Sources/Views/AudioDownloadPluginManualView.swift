import CisumUIComponents
import LumiUI
import SwiftUI

/// 下载管理 说明书 —— 章节式文档。
struct AudioDownloadPluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Download Manager", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Download and manage music files with offline playback support")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Download: downloads music locally.", bundle: .module)),
                .init(String(localized: "Offline: plays without a network after downloading.", bundle: .module)),
                .init(String(localized: "Queue: views and manages download tasks.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Select music to download and click Download.", bundle: .module)),
                .init(String(localized: "View progress in the download queue.", bundle: .module)),
                .init(String(localized: "Plays offline once downloaded.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Downloading requires a network connection.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
