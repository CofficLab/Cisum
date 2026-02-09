import SwiftUI

/// 用于预览当前插件ID值的视图
struct PluginRepoDebugView: View {
    @State private var currentPluginId: String = ""
    @State private var userDefaultsValue: String = ""
    @State private var iCloudValue: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("插件仓库调试视图").font(.headline)
            
            Divider()
            
            Group {
                Text("当前插件ID: \(currentPluginId)").bold()
                Text("UserDefaults 值: \(userDefaultsValue)")
                Text("iCloud 值: \(iCloudValue)")
            }
            .font(.system(.body, design: .monospaced))
            
            Divider()
            
            Button("刷新数据") {
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
        
        // 直接从 UserDefaults 获取值
        userDefaultsValue = UserDefaults.standard.string(forKey: PluginRepo.keyOfCurrentPluginID) ?? "未设置"
        
        // 直接从 iCloud 获取值
        iCloudValue = NSUbiquitousKeyValueStore.default.string(forKey: PluginRepo.keyOfCurrentPluginID) ?? "未设置"
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

#Preview("插件仓库调试") {
    PluginRepoDebugView()
}
