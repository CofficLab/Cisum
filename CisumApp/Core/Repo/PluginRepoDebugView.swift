import SwiftUI

/// View for previewing current plugin ID values
struct PluginRepoDebugView: View {
    @State private var currentPluginId: String = ""
    @State private var userDefaultsValue: String = ""
    @State private var iCloudValue: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plugin Repo Debug View").font(.headline)

            Divider()

            Group {
                Text("Current Plugin ID: \(currentPluginId)").bold()
                Text("UserDefaults value: \(userDefaultsValue)")
                Text("iCloud value: \(iCloudValue)")
            }
            .font(.system(.body, design: .monospaced))
            
            Divider()

            Button("Refresh Data") {
                refreshData()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            refreshData()
        }
    }
    
    /// 刷新显示的数据
    private func refreshData() {
        // 获取当前插件ID（通过 PluginRepo 的方法）
        let repo = PluginRepo()
        currentPluginId = repo.getCurrentPluginId()
        
        // Directly get value from UserDefaults
        userDefaultsValue = UserDefaults.standard.string(forKey: PluginRepo.keyOfCurrentPluginID) ?? "Not Set"

        // Directly get value from iCloud
        iCloudValue = NSUbiquitousKeyValueStore.default.string(forKey: PluginRepo.keyOfCurrentPluginID) ?? "Not Set"
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

#Preview("Plugin Repo Debug") {
    PluginRepoDebugView()
}
