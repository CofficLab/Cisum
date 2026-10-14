import ProviderDocsView
import KernelCore
import ProviderPlugin
import ProviderSettingView
import KitAppEvents
import SwiftUI
import Testing
@testable import PluginSettingGeneral

@MainActor
struct GeneralSettingsTests {
    @Test
    func viewModelDefaultsToNoManualsAndPreservesInjectedEntries() {
        let emptyViewModel = GeneralSettingsViewModel()
        #expect(emptyViewModel.manualEntries.isEmpty)

        let manuals = [
            DocsEntry(id: "audio", name: "Audio") { EmptyView() },
            DocsEntry(id: "storage", name: "Storage") { EmptyView() },
        ]
        let viewModel = GeneralSettingsViewModel(manualEntries: manuals)

        #expect(viewModel.manualEntries.map(\.id) == ["audio", "storage"])
        #expect(viewModel.manualEntries.map(\.name) == ["Audio", "Storage"])
    }

    @Test
    func pluginRegistersItsDocsAndContributesGeneralEntry() async throws {
        let docs = DefaultDocsViewProvider()
        let settings = DefaultSettingViewProviding()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any DocsViewProviding).self, docs)
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        let plugin = SettingGeneralPlugin()

        try await plugin.onRegister(kernel: kernel)
        try await plugin.onBootAsync(kernel: kernel)

        #expect(docs.aboutEntries.contains { $0.id == plugin.id })
        #expect(docs.manualEntries.contains { $0.id == plugin.id })
        #expect(plugin.addSettingView() == nil)

        // 入口经 SettingViewProviding 契约注入，宿主侧即可读到。
        let entry = try #require(settings.entries.first { $0.id == "general" })
        #expect(entry.title == "General")
        #expect(entry.systemImage == plugin.iconName)
        #expect(entry.order == plugin.order)
    }

    @Test
    func pluginDoesNotContributeEntryWithoutSettingsProvider() async throws {
        let kernel = KernelCoreContainer()
        let plugin = SettingGeneralPlugin()

        // 未注册 SettingViewProviding 时优雅降级，不应抛错。
        try await plugin.onBootAsync(kernel: kernel)

        #expect(plugin.makeSettingEntry() != nil)
    }

    @Test
    func pluginRegistrationIsSafeWithoutDocsProvider() async throws {
        let plugin = SettingGeneralPlugin()
        try await plugin.onRegister(kernel: KernelCoreContainer())
    }
}