import MagicKit
import SwiftUI

struct SystemSetting: View, SuperLog {
    nonisolated static let emoji = "⚙️"
    nonisolated static let verbose = false

    @EnvironmentObject var app: AppProvider
    @State private var showConfirmSheet: Bool = false

    var body: some View {
        MagicSettingSection(title: "APP 信息") {
            // 版本信息
            MagicSettingRow(title: "当前版本", description: "APP 的版本", icon: "info.circle", content: {
                Text(MagicApp.getVersion())
                    .font(.footnote)
            })

            // 重置设置
            MagicSettingRow(title: "重置设置", description: "重置设置，恢复成系统默认状态", icon: .iconReset) {
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
