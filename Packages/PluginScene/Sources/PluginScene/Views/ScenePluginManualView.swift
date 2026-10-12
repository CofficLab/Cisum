import CisumUIComponents
import LumiUI
import SwiftUI

/// 场景管理 说明书 —— 章节式文档。
struct ScenePluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Scene Management", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Manages app scene switching and state (Music Library / Audiobooks)")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Scene Switching: switches between the music library and audiobooks.", bundle: .module)),
                .init(String(localized: "State Management: maintains the current scene state.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Choose the target scene in the scene switcher.", bundle: .module)),
                .init(String(localized: "The app switches to the corresponding scene interface.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Scenes are built into the app and fixed as the music library and audiobooks.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
