import KernelCore
import ProviderDocsView
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
    func pluginRegistersItsDocsAndContributesGeneralNavigation() async throws {
        let docs = DefaultDocsViewProvider()
        let kernel = CisumKernelContainer()
        try kernel.registerDocsService(docs)
        let plugin = SettingGeneralPlugin()

        try await plugin.onRegister(kernel: kernel)
        try await plugin.onBoot(kernel: kernel)

        #expect(docs.aboutEntries.contains { $0.id == plugin.id })
        #expect(docs.manualEntries.contains { $0.id == plugin.id })
        #expect(plugin.addSettingView() == nil)

        let item = try #require(plugin.addSettingNavigationItem())
        #expect(item.id == "general")
        #expect(item.title == "General")
        #expect(item.order == SettingGeneralPlugin.metadata.order)
    }

    @Test
    func pluginRegistrationIsSafeWithoutDocsProvider() async throws {
        let plugin = SettingGeneralPlugin()
        try await plugin.onRegister(kernel: CisumKernelContainer())
    }
}
