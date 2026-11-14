import Foundation
import KernelCore
import ProviderToolbar
import Testing
@testable import PluginSettingsButton

#if os(iOS)
/// iOS 导航栏齿轮的生命周期行为。
///
/// iOS 没有独立的设置窗口 Scene：齿轮通过 `IOSNavigationBarProviding`
/// 贡献给宿主导航栏，点击后广播 `lumi.openSettings` 通知，由宿主以 sheet
/// 呈现设置页。
@MainActor
struct SettingsButtonPluginIOSLifecycleTests {
    /// 插件启动后必须真的把齿轮项注入导航栏 Provider。
    @Test
    func startAsyncRegistersNavigationBarItem() async throws {
        let kernel = KernelCoreContainer()
        let navigationBar = DefaultIOSNavigationBarProviding()
        try kernel.registerProvider((any IOSNavigationBarProviding).self, navigationBar)

        let plugin = SettingsButtonPlugin()
        try await kernel.startAsync(plugins: [plugin])

        let items = navigationBar.visibleNavigationBarItems
        #expect(items.count == 1)
        #expect(items.first?.id == SettingsButtonPluginInfo.navigationBarItemId)
        #expect(items.first?.placement == .trailing)
    }

    /// 关闭时必须撤回齿轮项，否则导航栏会留下一个点不动的悬空按钮。
    @Test
    func onShutdownAsyncRemovesNavigationBarItem() async throws {
        let kernel = KernelCoreContainer()
        let navigationBar = DefaultIOSNavigationBarProviding()
        try kernel.registerProvider((any IOSNavigationBarProviding).self, navigationBar)

        let plugin = SettingsButtonPlugin()
        try await kernel.startAsync(plugins: [plugin])
        #expect(navigationBar.visibleNavigationBarItems.count == 1)

        try await plugin.onShutdownAsync(kernel: kernel)

        #expect(navigationBar.visibleNavigationBarItems.isEmpty)
    }

    /// 没有导航栏 Provider 时启动阶段必须静默跳过，不得崩溃。
    @Test
    func startAsyncWithoutNavigationBarProviderIsSafe() async throws {
        let kernel = KernelCoreContainer()
        let plugin = SettingsButtonPlugin()

        try await kernel.startAsync(plugins: [plugin])

        #expect(kernel.registeredPluginCount == 1)
    }

    /// 齿轮项归属到本插件：插件被禁用时导航栏应隐藏该齿轮。
    @Test
    func navigationBarItemIsOwnedByPlugin() {
        let plugin = SettingsButtonPlugin()
        let item = plugin.makeNavigationBarItem()

        #expect(item.ownerPluginID == plugin.id)
    }
}
#endif
