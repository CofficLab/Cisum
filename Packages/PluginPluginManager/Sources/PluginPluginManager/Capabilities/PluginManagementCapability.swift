import CisumKernel
import ProviderPluginManaging
import MagicKit

/// 插件管理页面需要的最小管理能力。
///
/// Views 与 ViewModel 不直接依赖 Kernel 或 `PluginManaging`；Provider 由插件
/// 入口适配后注入 ViewModel。
@MainActor
protocol PluginManagementCapability: AnyObject {
    var configurablePlugins: [any SuperPlugin] { get }

    func isEnabled(id: String) -> Bool
    func enablePlugin(id: String) async -> Bool
    func disablePlugin(id: String) async -> Bool
}

/// 将内核插件管理 Provider 收窄成设置页所需的能力。
@MainActor
final class PluginManagementCapabilityAdapter: PluginManagementCapability, SuperLog {
    nonisolated static let verbose = false

    private weak var manager: (any PluginManaging)?

    init(manager: any PluginManaging) {
        self.manager = manager
    }

    var configurablePlugins: [any SuperPlugin] {
        manager?.configurablePlugins ?? []
    }

    func isEnabled(id: String) -> Bool {
        manager?.isEnabled(id: id) ?? false
    }

    func enablePlugin(id: String) async -> Bool {
        await manager?.enablePlugin(id: id) ?? false
    }

    func disablePlugin(id: String) async -> Bool {
        await manager?.disablePlugin(id: id) ?? false
    }
}
