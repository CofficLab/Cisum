import CisumUIComponents
import LumiUI
import SwiftUI

/// 文件日志 说明书 —— 章节式文档。
struct FileLogPluginManualView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(title: String(localized: "File Log", bundle: .module), subtitle: "User Manual")

            ManualSectionHeader(number: 1, title: String(localized: "Overview", bundle: .module))
            Text("Logs app runtime and file operations to help troubleshoot issues")
                .font(.appBody)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: String(localized: "Core Capabilities", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Logging: records key runtime events.", bundle: .module)),
                .init(String(localized: "Search Logs: searches logs by keyword.", bundle: .module)),
                .init(String(localized: "Clean Up: clears historical logs.", bundle: .module)),
            ])

            ManualSectionHeader(number: 3, title: String(localized: "Basic Operations", bundle: .module))
            ManualStepList(items: [
                .init(String(localized: "Opens the log view to inspect records.", bundle: .module)),
                .init(String(localized: "Searches by keyword to locate issues.", bundle: .module)),
                .init(String(localized: "Periodically clears expired logs.", bundle: .module)),
            ])

            ManualSectionHeader(number: 4, title: String(localized: "Notes", bundle: .module))
            ManualBulletList(items: [
                .init(String(localized: "Available on macOS only.", bundle: .module)),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }
}
