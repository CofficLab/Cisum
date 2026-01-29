import MagicKit
import OSLog
import SwiftUI

/**
 * 演示模式插件
 */
actor AudioDemoPlugin: SuperPlugin {
    
    static var shouldRegister: Bool { true }
    static var order: Int { 1 }

    let title = "音频仓库"
    let description = "音频文件数据库视图"
    let iconName = "externaldrive"

    @MainActor
    func addTabView(reason: String, currentSceneName: String?, demoMode: Bool = false) -> (view: AnyView, label: String)? {
        guard currentSceneName == AudioScenePlugin.sceneName else { return nil }

        return (AnyView(AudioListDemo()), "音乐仓库")
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
        .showTabView()
        .inDemoMode()
        .withDebugBar()
}

#Preview("App Store Album Art") {
    AppStoreAlbumArt()
        .inMagicContainer(.macBook13, scale: 1)
}
