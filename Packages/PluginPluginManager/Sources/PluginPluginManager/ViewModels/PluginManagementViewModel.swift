import Combine
import Foundation
import KernelCore
import ProviderPlugin
import ProviderPluginManaging
import MagicKit

/// 插件管理视图的状态容器（迁移 Phase 4）。
///
/// 持有插件启停变化的版本号，收到通知时递增以强制列表重建；
/// 取代原 `PluginManagementView` 的 `@State revision` + `.onReceive`。
@MainActor
final class PluginManagementViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    /// 插件启停变化版本号：递增时强制列表重建。
    @Published private(set) var revision = 0

    private weak var manager: (any PluginManaging)?

    init(manager: (any PluginManaging)? = nil) {
        self.manager = manager
    }

    var plugins: [any SuperPlugin] {
        manager?.configurablePlugins ?? []
    }

    func isEnabled(id: String) -> Bool {
        manager?.isEnabled(id: id) ?? false
    }

    func setEnabled(_ enabled: Bool, for pluginID: String) async -> Bool {
        if enabled {
            return await manager?.enablePlugin(id: pluginID) ?? false
        }
        return await manager?.disablePlugin(id: pluginID) ?? false
    }

    func incrementRevision() {
        revision += 1
    }
}
