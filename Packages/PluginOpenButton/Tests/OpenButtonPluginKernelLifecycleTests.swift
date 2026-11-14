import Foundation
import KernelCore
import ProviderDocsView
import ProviderPlayback
import ProviderPlugin
import SwiftUI
import Testing
@testable import PluginOpenButton

/// 打开按钮插件经**内核**驱动的真实生命周期。
///
/// ## 为什么另起一个测试文件
///
/// `OpenButtonPlugin` 实现的是 `onBootAsync` / `onReadyAsync` / `onShutdownAsync`，
/// 而协议扩展里的同步 `onBoot(kernel:)` 是**默认空实现**。
/// 直接调用同步版本不会执行插件真正的启动逻辑：内核引用没有被保存，
/// 工具栏按钮也就从未被登记到贡献注册表——既有断言只检查了插件自身的
/// `addToolBarButtons()`，看不到按钮是否真的进了注册表。
///
/// 这里的用例一律用 `kernel.startAsync(plugins:)` 驱动真实生命周期，
/// 并从贡献注册表这一侧断言结果。
@MainActor
struct OpenButtonPluginKernelLifecycleTests {
    /// 启动后：工具栏按钮真的登记在贡献注册表里，文档条目也注入了文档 Provider。
    @Test
    func startAsyncRegistersToolbarButtonAndDocsEntries() async throws {
        let kernel = KernelCoreContainer()
        let contributions = PluginContributionService(kernel: kernel)
        try kernel.registerProvider((any PluginContributionProviding).self, contributions)
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)
        let playback = PluginPlaybackProbe()
        try kernel.registerProvider((any PlaybackProviding).self, playback)

        let plugin = OpenButtonPlugin()
        try await kernel.startAsync(plugins: [plugin])

        #if os(macOS)
        let buttons = contributions.getToolBarButtons()
        #expect(buttons.count == 1)
        #expect(buttons.first?.id == OpenButtonPluginInfo.toolbarItemId)
        #endif

        #expect(docs.aboutEntries.count == 1)
        #expect(docs.aboutEntries.first?.id == plugin.id)
        #expect(docs.aboutEntries.first?.name == plugin.metadata.name)
        #expect(docs.manualEntries.count == 1)
        #expect(docs.manualEntries.first?.id == plugin.id)
        #expect(docs.manualEntries.first?.name == plugin.metadata.name)
    }

    /// 文档条目必须能产出**对应**的视图：关于页与说明书页不能是同一个视图，
    /// 否则宿主点开「说明书」会看到「关于」的内容。
    @Test
    func docsEntriesProduceTheirOwnViews() async throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = OpenButtonPlugin()
        try await kernel.startAsync(plugins: [plugin])

        let aboutDescription = String(describing: docs.aboutEntries[0].makeView())
        let manualDescription = String(describing: docs.manualEntries[0].makeView())

        #expect(aboutDescription != manualDescription)
    }

    /// 关闭时必须撤回工具栏贡献——否则窗口上会留下一个点不动的悬空按钮。
    @Test
    func onShutdownAsyncRemovesToolbarContribution() async throws {
        let kernel = KernelCoreContainer()
        let contributions = PluginContributionService(kernel: kernel)
        try kernel.registerProvider((any PluginContributionProviding).self, contributions)
        let playback = PluginPlaybackProbe()
        try kernel.registerProvider((any PlaybackProviding).self, playback)

        let plugin = OpenButtonPlugin()
        try await kernel.startAsync(plugins: [plugin])
        #if os(macOS)
        #expect(contributions.getToolBarButtons().count == 1)
        #endif

        try await plugin.onShutdownAsync(kernel: kernel)

        #if os(macOS)
        #expect(contributions.getToolBarButtons().isEmpty)
        #endif
    }

    /// 禁用后应拆除状态：插件自己不再持有按钮视图。
    ///
    /// 注册表里的撤回由内核负责（`disablePlugin` 在 `onDisable` 之后统一清理），
    /// 插件这一侧只负责停止持有状态。
    @Test
    func onDisableTearsDownPluginState() async throws {
        let kernel = KernelCoreContainer()
        let playback = PluginPlaybackProbe()
        try kernel.registerProvider((any PlaybackProviding).self, playback)

        let plugin = OpenButtonPlugin()
        try await kernel.startAsync(plugins: [plugin])
        #if os(macOS)
        #expect(plugin.addToolBarButtons().count == 1)
        #endif

        try await plugin.onDisable(kernel: kernel)

        #if os(macOS)
        #expect(plugin.addToolBarButtons().isEmpty)
        #endif
    }

    /// 重新启用后按钮应重新出现。
    @Test
    func onEnableRestoresToolbarButton() async throws {
        let kernel = KernelCoreContainer()
        let playback = PluginPlaybackProbe()
        try kernel.registerProvider((any PlaybackProviding).self, playback)

        let plugin = OpenButtonPlugin()
        try await kernel.startAsync(plugins: [plugin])
        try await plugin.onDisable(kernel: kernel)
        try await plugin.onEnable(kernel: kernel)

        #if os(macOS)
        #expect(plugin.addToolBarButtons().count == 1)
        #endif
    }

    /// 没有播放 Provider 时不得贡献工具栏按钮：没有当前文件就无从「在 Finder 中显示」。
    @Test
    func noToolbarButtonWithoutPlaybackProvider() async throws {
        let kernel = KernelCoreContainer()
        let contributions = PluginContributionService(kernel: kernel)
        try kernel.registerProvider((any PluginContributionProviding).self, contributions)

        let plugin = OpenButtonPlugin()
        try await kernel.startAsync(plugins: [plugin])

        #if os(macOS)
        #expect(contributions.getToolBarButtons().isEmpty)
        #endif
    }
}
