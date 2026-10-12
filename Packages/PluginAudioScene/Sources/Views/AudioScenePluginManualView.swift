import CisumUIComponents
import LumiUI
import SwiftUI

/// 音乐场景 说明书 —— 章节式文档。
struct AudioScenePluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Music Scene", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Provides the Music Library scene, the main entry for music features")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Music Library: the main interface of the music scene.", bundle: .module)),
                .init(String(localized: "Scene Switching: switches exclusively with other scenes (audiobooks).", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Enter the music library from the scene switcher.", bundle: .module)),
                .init(String(localized: "Browse and play music.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Scenes are built into the app and cannot be extended.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
