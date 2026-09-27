import CisumUIComponents
import LumiUI
import SwiftUI

/// 音乐库 说明书 —— 章节式文档。
struct AudioPluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Music Library", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Manage, browse, and play local music files")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Media Library: manages local music files and browses by category.", bundle: .module)),
                .init(String(localized: "Search: quickly find music by name.", bundle: .module)),
                .init(String(localized: "Play: starts playback from the music library.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Opens the music library scene to browse all music.", bundle: .module)),
                .init(String(localized: "Use the search field to filter music by name.", bundle: .module)),
                .init(String(localized: "Click any music to start playing.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "The music library depends on a local storage location; configure it in Settings first.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
