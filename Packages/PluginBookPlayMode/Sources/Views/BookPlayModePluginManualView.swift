import CisumUIComponents
import LumiUI
import SwiftUI

/// 有声书播放模式 说明书 —— 章节式文档。
struct BookPlayModePluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Audiobook Play Mode", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Switch playback modes: single chapter loop, list loop, shuffle, and more")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Repeat: single-chapter / list repeat.", bundle: .module)),
                .init(String(localized: "Shuffle: shuffles all chapters.", bundle: .module)),
                .init(String(localized: "Sequential: plays in list order.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Click the play-mode button in the player control area.", bundle: .module)),
                .init(String(localized: "Switches between single-chapter repeat, list repeat, and shuffle.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "The play mode applies to the current playlist.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
