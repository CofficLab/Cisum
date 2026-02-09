import MagicKit
import OSLog
import SwiftData
import SwiftUI

struct BtnScene: View {
    @EnvironmentObject var p: PluginProvider

    @State private var isPresented: Bool = false

    var body: some View {
        if let sceneName = p.currentSceneName {
            Button(action: {
                self.isPresented.toggle()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: sceneIcon(for: sceneName))
                    Text(sceneName)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            }
            .popover(isPresented: self.$isPresented, content: {
                Posters(
                    isPresented: $isPresented
                )
                .frame(minWidth: Config.minWidth)
            })
        }
    }

    /// 根据场景名称返回对应的图标
    private func sceneIcon(for sceneName: String) -> String {
        // 从插件系统中获取图标
        if let plugin = p.plugin(for: sceneName) {
            return plugin.iconName
        }
        // 如果找不到插件，使用默认图标
        return "circle"
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
