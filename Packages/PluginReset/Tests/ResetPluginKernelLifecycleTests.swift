import Foundation
import KernelCore
import ProviderDocsView
import ProviderPlugin
import ProviderSettingView
import SwiftUI
import Testing
@testable import PluginReset

/// 复位插件经**内核**驱动的真实生命周期。
///
/// ## 为什么另起一个测试文件
///
/// `SystemPlugin` 实现的是 `onBootAsync` / `onShutdownAsync`，
/// 而协议扩展里的同步 `onBoot(kernel:)` 是**默认空实现**。
/// 既有测试调用的正是那个空实现，因此插件真正的启动逻辑从未执行：
/// 设置入口从未被登记到设置 Provider，既有断言也只能绕开内核
/// 直接调 `makeSettingEntry()` 来验证。
///
/// 这里的用例一律调用插件自己的异步生命周期方法，并从 Provider 一侧断言结果。
@MainActor
struct ResetPluginKernelLifecycleTests {
    /// 启动后：设置入口真的登记到了设置 Provider。
    @Test
    func onBootAsyncRegistersSettingEntryIntoSettingsProvider() async throws {
        let kernel = KernelCoreContainer()
        let contributions = PluginContributionService(kernel: kernel)
        try kernel.registerProvider((any PluginContributionProviding).self, contributions)
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = SystemPlugin()
        try await plugin.onBootAsync(kernel: kernel)

        #expect(settings.entries.count == 1)
        #expect(settings.entries.first?.id == "system")
        #expect(settings.entries.first?.title == ResetPluginInfo.title)
        #expect(settings.entries.first?.order == ResetPluginInfo.order)
    }

    /// 现状行为：没有贡献注册表时，设置入口**不会**被登记。
    ///
    /// 插件的 `onBootAsync` 把「是否登记设置入口」挂在贡献注册表是否存在上
    /// （绑定的 `contrib` 并未被使用），这里按实现钉住这条行为，
    /// 避免它被无意改掉时无人察觉。
    @Test
    func onBootAsyncSkipsSettingEntryWithoutContributionProvider() async throws {
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = SystemPlugin()
        try await plugin.onBootAsync(kernel: kernel)

        #expect(settings.entries.isEmpty)
    }

    /// 关闭时必须撤回设置入口，否则设置里会留下一个点不动的死入口。
    @Test
    func onShutdownAsyncRemovesSettingEntry() async throws {
        let kernel = KernelCoreContainer()
        let contributions = PluginContributionService(kernel: kernel)
        try kernel.registerProvider((any PluginContributionProviding).self, contributions)
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = SystemPlugin()
        try await plugin.onBootAsync(kernel: kernel)
        #expect(settings.entries.count == 1)

        try await plugin.onShutdownAsync(kernel: kernel)

        #expect(settings.entries.isEmpty)
    }

    /// 注册阶段要把「关于」与「说明书」条目注入文档 Provider。
    @Test
    func onRegisterPublishesAboutAndManualDocsEntries() async throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = SystemPlugin()
        try plugin.onRegister(kernel: kernel)

        #expect(docs.aboutEntries.count == 1)
        #expect(docs.aboutEntries.first?.id == plugin.id)
        #expect(docs.aboutEntries.first?.name == plugin.metadata.name)
        #expect(docs.manualEntries.count == 1)
        #expect(docs.manualEntries.first?.id == plugin.id)
        #expect(docs.manualEntries.first?.name == plugin.metadata.name)
    }

    /// 文档条目与设置入口都必须能产出**对应**的视图：
    /// 关于页、说明书页、设置详情页不能是同一个视图。
    @Test
    func docsAndSettingEntriesProduceDistinctViews() async throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = SystemPlugin()
        try plugin.onRegister(kernel: kernel)

        let aboutDescription = String(describing: docs.aboutEntries[0].makeView())
        let manualDescription = String(describing: docs.manualEntries[0].makeView())
        let detailDescription = String(describing: plugin.makeSettingEntry()?.makeDetailView())

        #expect(aboutDescription != manualDescription)
        #expect(!detailDescription.isEmpty)
        #expect(detailDescription != aboutDescription)
        #expect(detailDescription != manualDescription)
    }
}
