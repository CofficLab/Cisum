import MagicKit
import OSLog
import SwiftData
import SwiftUI

/// 服务提供者管理器
/// 负责创建和管理应用程序的核心服务和提供者
/// 不再是单例，每次调用 create() 都会创建新的实例
@MainActor
final class ProviderManager: SuperLog {
    static let verbose = false
    nonisolated static let emoji = "🔧"

    // Providers
    let app: AppProvider
    let stateMessageProvider: StateProvider
    let plugin: PluginProvider
    let cloud: CloudProvider

    // PlayMan
    let man: PlayMan

    /// 创建新的 ProviderManager 实例
    /// 每次调用都会创建新的 Provider 实例
    init() {
        // Repos
        let pluginRepo = PluginRepo()
        let uiRepo = UIRepo()

        // Providers
        self.app = AppProvider(uiRepo: uiRepo)
        self.stateMessageProvider = StateProvider()
        self.plugin = PluginProvider(repo: pluginRepo)
        self.cloud = CloudProvider()

        // PlayMan
        self.man = PlayMan(
            verbose: Self.verbose,
            locale: .current,
            defaultArtwork: Image.musicFill,
            defaultArtworkBuilder: {
                LogoView()
            }
        )

        if Self.verbose {
            os_log("\(Self.t)✅ 服务提供者初始化完成")
        }
    }

    /// 兼容旧代码：提供 shared 单例（已废弃，建议使用 App 层面的 Provider）
    @available(*, deprecated, message: "使用 App 层面的 Provider 替代单例")
    @MainActor
    static var shared: ProviderManager {
        // 为了向后兼容，仍然提供单例
        // 但建议在 App 层面创建 Provider 并通过环境传递
        struct SharedHolder {
            @MainActor
            static let instance = ProviderManager()
        }
        return SharedHolder.instance
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
