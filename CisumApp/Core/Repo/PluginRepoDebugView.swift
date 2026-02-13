import SwiftUI

/// View for previewing current plugin ID values
struct PluginRepoDebugView: View {
    @State private var currentPluginId: String = ""
    @State private var userDefaultsValue: String = ""
    @State private var iCloudValue: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plugin Repo Debug View", tableName: "Core").font(.headline)

            Divider()

            Group {
                Text("Current Plugin ID: \(currentPluginId)", tableName: "Core").bold()
                Text("UserDefaults value: \(userDefaultsValue)", tableName: "Core")
                Text("iCloud value: \(iCloudValue)", tableName: "Core")
            }
            .font(.system(.body, design: .monospaced))
            
            Divider()

            Button {
                refreshData()
            } label: {
                Text("Refresh Data", tableName: "Core")
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
