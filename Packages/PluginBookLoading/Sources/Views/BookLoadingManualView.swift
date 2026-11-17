import LumiUI
import SwiftUI

/// 有声书载入 说明书 —— 章节式文档。
struct BookLoadingManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "Book Loading", bundle: .module), subtitle: String(localized: "User Manual", bundle: .module))

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Shows the iCloud loading banner for audiobooks in the player control area.", bundle: .module)
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Named loading: shows which chapter is being fetched and how far it has gone.", bundle: .module)),
                .init(String(localized: "Cancel: stops waiting without treating it as a failure.", bundle: .module)),
                .init(String(localized: "Retry: re-runs the last failed load from the same start time.", bundle: .module)),
                .init(String(localized: "Plain-language failures: the engine detail stays in the tooltip and accessibility hint.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Tap an audiobook tile to start loading its chapter.", bundle: .module)),
                .init(String(localized: "While it loads, tap Cancel to stop waiting.", bundle: .module)),
                .init(String(localized: "If loading fails, tap Retry to run it again.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "The banner only appears in the audiobooks scene.", bundle: .module)),
                .init(String(localized: "Cancelling keeps the iCloud transfer running in the background.", bundle: .module)),
                .init(String(localized: "The banner replaces the state and progress rows so the control area never changes height.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
