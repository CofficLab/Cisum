import Foundation
import KernelCore
import ProviderDocsView
import ProviderPlugin
import ProviderSettingView
import SwiftUI
import Testing
@testable import PluginSettingGeneral

/// 通用设置插件的生命周期：入口登记与撤回、文档条目、详情视图构造。
@MainActor
struct SettingGeneralPluginLifecycleTests {
    /// 启动时必须把「通用」入口登记到设置 Provider 上。
    @Test
    func bootRegistersGeneralSettingsEntry() async throws {
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = SettingGeneralPlugin()
        try await kernel.startAsync(plugins: [plugin])

        let entry = try #require(settings.entries.first { $0.id == "general" })
        #expect(entry.title == "General")
        #expect(entry.systemImage == plugin.iconName)
    }

    /// 关闭时必须撤回入口——否则设置窗口里会留下一个点不动的入口。
    @Test
    func onShutdownAsyncRemovesGeneralSettingsEntry() async throws {
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = SettingGeneralPlugin()
        try await plugin.onBootAsync(kernel: kernel)
        #expect(settings.entries.contains { $0.id == "general" })

        try await plugin.onShutdownAsync(kernel: kernel)

        #expect(!settings.entries.contains { $0.id == "general" })
    }

    /// 插件不提供独立设置视图：入口只通过 `SettingViewProviding` 契约注入，
    /// 因此贡献注册表里不应出现任何设置视图。
    @Test
    func pluginContributesNoStandaloneSettingView() async throws {
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        let contributions = PluginContributionService(kernel: kernel)
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider((any PluginContributionProviding).self, contributions)

        let plugin = SettingGeneralPlugin()
        try await kernel.startAsync(plugins: [plugin])

        #expect(plugin.addSettingView() == nil)
        #expect(contributions.getSettingViews().isEmpty)
        #expect(settings.entries.contains { $0.id == "general" })
    }

    /// 文档条目必须能产出**各自**的视图：关于页与说明书页不能是同一个视图。
    @Test
    func docsEntriesProduceTheirOwnViews() async throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = SettingGeneralPlugin()
        try plugin.onRegister(kernel: kernel)

        let aboutDescription = String(describing: docs.aboutEntries[0].makeView())
        let manualDescription = String(describing: docs.manualEntries[0].makeView())

        #expect(aboutDescription != manualDescription)
        #expect(aboutDescription == String(describing: AnyView(SettingGeneralPluginAboutView())))
        #expect(manualDescription == String(describing: AnyView(SettingGeneralPluginManualView())))
    }

    /// 详情视图必须能被构造出来——否则设置窗口点开「通用」是一张白页。
    ///
    /// 详情在构造时读取文档 Provider 的说明书条目作为数据源。
    @Test
    func settingsEntryDetailViewIsBuildable() async throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)
        docs.addManual(DocsEntry(id: "audio", name: "Audio") { EmptyView() })

        let plugin = SettingGeneralPlugin()
        try await plugin.onBootAsync(kernel: kernel)

        let entry = try #require(plugin.makeSettingEntry())
        let detailDescription = String(describing: entry.makeDetailView())

        #expect(detailDescription.contains("GeneralSettingsDetailView"))
    }
}
