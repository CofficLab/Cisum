import Foundation
import KernelCore
import Testing
@testable import FactoryCisum

/// 插件管理器插件在 Cisum 中的启用状态守卫。
///
/// Cisum 的插件策略全是 `alwaysOn` / `disabled`，没有用户可配置的插件 ——
/// 插件管理页在本宿主必然是一个永远为空的列表。因此 Cisum 把插件管理器
/// 配成 `.disabled`：内核启动时彻底排除它（不注册、不启动、不展示），
/// 设置侧边栏也就不会出现「插件管理」入口。
///
/// 这个守卫固化该决策，防止迁移到共享远程包时不慎把策略改回 `.required`，
/// 导致设置侧边栏多出一个点进去什么都没有的死路。
@MainActor
@Suite("插件管理器启用状态")
struct PluginManagerEnablementTests {
    /// 插件管理器插件的唯一标识。
    private static let pluginManagerID = "com.coffic.cisum.plugin.plugin-manager"

    /// 插件管理器在 Cisum 的插件目录里必须是 `.disabled` 策略。
    @Test("插件管理器在 Cisum 是 disabled 策略")
    func pluginManagerIsDisabled() {
        let plugin = DefaultPluginFactory().makePlugins()
            .first { $0.id == Self.pluginManagerID }

        #expect(
            plugin != nil,
            "插件目录里应包含插件管理器（id：\(Self.pluginManagerID)）"
        )
        #expect(
            plugin?.metadata.policy == .disabled,
            "Cisum 没有用户可配置的插件，插件管理器必须是 .disabled 策略"
        )
    }

    /// `.disabled` 的插件不会被内核启动，也就不会出现在设置侧边栏。
    @Test("disabled 策略的插件不会被内核启动")
    func disabledPluginIsNotStarted() async throws {
        let kernel = KernelCoreContainer()
        let plugin = try #require(
            DefaultPluginFactory().makePlugins().first { $0.id == Self.pluginManagerID }
        )
        #expect(plugin.metadata.policy == .disabled)

        // 内核在启动前按策略过滤：`.disabled` 的插件不注册、不启动。
        let activePlugins = DefaultPluginFactory().makePlugins()
            .filter { $0.metadata.policy != .disabled }

        try await kernel.startAsync(plugins: activePlugins)

        #expect(
            !kernel.isPluginRegistered(id: Self.pluginManagerID),
            "`.disabled` 的插件不应被注册"
        )
    }
}
