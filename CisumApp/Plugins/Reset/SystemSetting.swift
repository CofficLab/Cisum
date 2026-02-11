import MagicKit
import SwiftUI

struct SystemSetting: View, SuperLog {
    nonisolated static let emoji = "⚙️"
    nonisolated static let verbose = false

    @EnvironmentObject var app: AppProvider
    @State private var showConfirmSheet: Bool = false

    var body: some View {
        MagicSettingSection(title: "App Information") {
            // Version information
            MagicSettingRow(title: "Current Version", description: "App version", icon: "info.circle", content: {
                Text(MagicApp.getVersion())
                    .font(.footnote)
            })

            // Reset settings
            MagicSettingRow(title: "Reset Settings", description: "Reset settings to system default state", icon: .iconReset) {
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
