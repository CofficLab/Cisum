import Foundation
import KernelCore
import Testing

@testable import Cisum

/// 插件管理器插件在 Cisum 中的启用状态守卫。
///
/// Cisum 按模块开放启停：书库、视频库、欢迎页、仓库引导等外围模块是
/// `enabledByDefault`，用户可在「插件管理」里关闭；音频核心、播放控制、
/// 数据层与宿主基础设施保持 `alwaysOn` / `required`。
///
/// 这个守卫固化该决策：插件管理器必须启用，并且至少存在可配置插件，
/// 否则设置侧边栏要么缺少入口，要么入口点进去是空列表。
@MainActor
@Suite("插件管理器启用状态")
struct PluginManagerEnablementTests {
    /// 插件管理器插件的唯一标识。
    private static let pluginManagerID = "com.coffic.cisum.plugin.plugin-manager"

    /// 插件管理器在 Cisum 的插件目录里必须是 `.required` 策略。
    @Test("插件管理器在 Cisum 是 required 策略")
    func pluginManagerIsRequired() {
        let plugin = CisumPluginFactory.makePlugins()
            .first { $0.id == Self.pluginManagerID }

        #expect(
            plugin != nil,
            "插件目录里应包含插件管理器（id：\(Self.pluginManagerID)）"
        )
        #expect(
            plugin?.metadata.policy == .required,
            "插件管理器必须启用，否则用户没有管理插件的入口"
        )
    }

    /// 插件目录里必须有用户可配置的插件，否则「插件管理」入口不会注册。
    @Test("插件目录包含用户可配置插件")
    func pluginCatalogHasConfigurablePlugins() {
        let configurablePlugins = CisumPluginFactory.makePlugins()
            .filter { $0.metadata.policy.isConfigurable }

        #expect(!configurablePlugins.isEmpty)
    }

    /// `.required` 的插件管理器会被内核注册并启动。
    @Test("required 策略的插件管理器会被内核启动")
    func requiredPluginIsStarted() async throws {
        let kernel = KernelCoreContainer()

        // 内核在启动前按策略过滤：`.disabled` 的插件不注册、不启动。
        let activePlugins = CisumPluginFactory.makePlugins()
            .filter { $0.metadata.policy != .disabled }

        try await kernel.startAsync(plugins: activePlugins)

        #expect(
            kernel.isPluginRegistered(id: Self.pluginManagerID),
            "启用策略的插件管理器应被内核注册"
        )
    }
}
