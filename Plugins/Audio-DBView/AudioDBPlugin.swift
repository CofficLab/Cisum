import MagicKit
import OSLog
import SwiftUI

/**
 * 音频数据库插件：提供音频仓库列表视图。
 */
actor AudioDBPlugin: SuperPlugin {
    static var shouldRegister: Bool { true }
    static var order: Int { 1 }

    let title = "音频仓库"
    let description = "音频文件数据库视图"
    let iconName = "externaldrive"

    @MainActor
    func addTabView(reason: String, currentSceneName: String?, demoMode: Bool = false) -> (view: AnyView, label: String)? {
        guard currentSceneName == AudioScenePlugin.sceneName else { return nil }
        guard demoMode == false else { return nil }

        return (AnyView(AudioDBView()), "音乐仓库")
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

#Preview("App - Demo") {
    ContentView()
        .inRootView()
        .inDemoMode()
        .withDebugBar()
}
