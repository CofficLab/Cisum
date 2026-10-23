import Foundation
import KernelCore
import ProviderDocsView
import ProviderPlugin
import SwiftUI
import Testing
@testable import PluginSettingsButton

/// 设置按钮插件的**真实**生命周期行为。
///
/// ## 为什么另起一个测试文件
///
/// `SettingsButtonPlugin` 只实现了 `onBootAsync` / `onShutdownAsync`，
/// 而 `SuperPlugin.onBoot(kernel:)` / `onShutdown(kernel:)` 在协议扩展里是
/// **默认空实现**。直接调用同步版本不会触发插件真正的启动逻辑，
/// 因此这里的用例一律通过 `kernel.startAsync(plugins:)` 驱动真实生命周期。
@MainActor
struct SettingsButtonPluginLifecycleTests {
    /// 工具栏按钮在插件启动后必须真的出现在贡献注册表里。
    @Test
    func startAsyncRegistersToolbarButtonForEnabledPlugin() async throws {
        let kernel = KernelCoreContainer()
        let contributions = PluginContributionService(kernel: kernel)
        try kernel.registerProvider((any PluginContributionProviding).self, contributions)

        let plugin = SettingsButtonPlugin()
        try await kernel.startAsync(plugins: [plugin])

        let buttons = contributions.getToolBarButtons()
        #expect(buttons.count == 1)
        #expect(buttons.first?.id == SettingsButtonPluginInfo.toolbarItemId)
    }

    /// 关闭时必须撤回工具栏贡献——否则窗口上会留下一个点不动的悬空按钮。
    ///
    /// 这里直接调用 `onShutdownAsync`（而不是 `stopAsync`），以便插件仍然
    /// 处于「已注册且启用」状态：若撤回逻辑失效，按钮仍会被聚合出来。
    @Test
    func onShutdownAsyncRemovesToolbarContribution() async throws {
        let kernel = KernelCoreContainer()
        let contributions = PluginContributionService(kernel: kernel)
        try kernel.registerProvider((any PluginContributionProviding).self, contributions)

        let plugin = SettingsButtonPlugin()
        try await kernel.startAsync(plugins: [plugin])
        #expect(contributions.getToolBarButtons().count == 1)

        try await plugin.onShutdownAsync(kernel: kernel)

        #expect(contributions.getToolBarButtons().isEmpty)
    }

    /// 注册阶段要把「关于」与「说明书」条目注入文档 Provider。
    @Test
    func onRegisterPublishesAboutAndManualDocsEntries() async throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = SettingsButtonPlugin()
        try await kernel.startAsync(plugins: [plugin])

        #expect(docs.aboutEntries.count == 1)
        #expect(docs.aboutEntries.first?.id == plugin.id)
        #expect(docs.aboutEntries.first?.name == plugin.metadata.name)
        #expect(docs.manualEntries.count == 1)
        #expect(docs.manualEntries.first?.id == plugin.id)
        #expect(docs.manualEntries.first?.name == plugin.metadata.name)
    }

    /// 没有文档 Provider 时注册阶段必须静默跳过，不得崩溃。
    @Test
    func onRegisterWithoutDocsProviderIsSafe() async throws {
        let kernel = KernelCoreContainer()
        let plugin = SettingsButtonPlugin()

        try await kernel.startAsync(plugins: [plugin])

        #expect(kernel.registeredPluginCount == 1)
    }

    /// 文档条目必须能产出**对应**的视图：关于页与说明书页不能是同一个视图，
    /// 否则宿主点开「说明书」会看到「关于」的内容。
    @Test
    func docsEntriesProduceTheirOwnViews() async throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = SettingsButtonPlugin()
        try await kernel.startAsync(plugins: [plugin])

        let aboutDescription = String(describing: docs.aboutEntries[0].makeView())
        let manualDescription = String(describing: docs.manualEntries[0].makeView())

        #expect(aboutDescription != manualDescription)
        #expect(aboutDescription == String(describing: AnyView(SettingsButtonPluginAboutView())))
        #expect(manualDescription == String(describing: AnyView(SettingsButtonPluginManualView())))
    }

    /// `shared` 单例与新建实例共享同一身份，供宿主侧统一引用。
    @Test
    func sharedSingletonKeepsPluginIdentity() {
        let shared = SettingsButtonPlugin.shared

        #expect(shared.id == SettingsButtonPlugin().id)
        #expect(shared.id == "SettingsButtonPlugin")
        #expect(SettingsButtonPlugin.verbose == false)
    }
}
