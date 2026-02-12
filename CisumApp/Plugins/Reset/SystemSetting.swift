import MagicKit
import SwiftUI

struct SystemSetting: View, SuperLog {
    nonisolated static let emoji = "⚙️"
    nonisolated static let verbose = false

    @EnvironmentObject var app: AppProvider
    @State private var showConfirmSheet: Bool = false

    var body: some View {
        MagicSettingSection(title: String(localized: "App Information", table: "Reset")) {
            // Version information
            MagicSettingRow(title: String(localized: "Current Version", table: "Reset"), description: String(localized: "App version", table: "Reset"), icon: "info.circle", content: {
                Text(MagicApp.getVersion())
                    .font(.footnote)
            })

            // Reset settings
            MagicSettingRow(title: String(localized: "Reset Settings", table: "Reset"), description: String(localized: "Reset settings to system default state", table: "Reset"), icon: .iconReset) {
                Image.reset
                    .frame(width: 28, height: 28)
                    .background(.regularMaterial, in: Circle())
                    .shadowSm()
                    .hoverScale(105)
                    .inButtonWithAction {
                        showConfirmSheet = true
                    }
            }
        }
        .sheet(isPresented: $showConfirmSheet) {
            ResetConfirm()
                .frame(width: 400)
        }
    }
}

// MARK: - Preview

#Preview("SystemSetting") {
    SystemSetting()
        .inRootView()
        .frame(height: 800)
}

#Preview("App - Large") {
    ContentView()
        .inRootView()
        .frame(width: 600, height: 1000)
}

#Preview("App - Small") {
    ContentView()
        .inRootView()
        .frame(width: 600, height: 600)
}

#if os(iOS)
    #Preview("iPhone") {
        ContentView()
            .inRootView()
    }
#endif
