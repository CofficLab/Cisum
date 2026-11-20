import Foundation
import KernelCore
import PluginRootView
import ProviderCloudDownload
import ProviderContentView
import ProviderControlView
import ProviderRootView
import ProviderSettingView
import ProviderTheme
import Testing

@testable import Cisum

/// 组合根清单（`CisumManifest` + `CisumPluginFactory` + `CisumHostWiring`）的装配契约。
@MainActor
struct CisumManifestTests {
    @Test
    func pluginFactoryProducesUniquePluginIDs() {
        let plugins = CisumPluginFactory.makePlugins()
        let ids = plugins.map(\.id)

        #expect(ids.count > 30)
        #expect(Set(ids).count == ids.count)
    }

    @Test
    func hostWiringFallsBackWhenRootProviderIsMissing() {
        CisumHostWiring.wire(KernelCoreContainer())
    }

    @Test
    func hostWiringInjectsControlAndContentProviders() throws {
        let kernel = KernelCoreContainer()
        let root = RootViewProvider(kernel: kernel)
        let control = DefaultControlViewProvider()
        let content = DefaultContentViewProvider()
        try kernel.registerProvider((any RootViewProviding).self, root)
        try kernel.registerProvider((any ControlViewProviding).self, control)
        try kernel.registerProvider((any ContentViewProviding).self, content)

        CisumHostWiring.wire(kernel)

        #expect(root.controlView != nil)
        #expect(root.contentView != nil)
        #expect(!control.isDemoMode)
        #expect(!content.isDemoMode)
        #expect(content.tabs.isEmpty)

        CisumHostWiring.release(kernel)
    }

    @Test
    func kernelLoadsThemeContributionsAfterPluginStartup() async throws {
        let kernel = try await CisumKernelFixture.makeKernel()
        let theme = try #require(kernel.resolveProvider((any ThemeProviding).self))
        // Cisum 只加载白名单内的目录主题（见 `CisumThemeSelection`），
        // 加上 ProviderTheme 内置的三个基础外观。
        #expect(theme.themes.count == CisumThemeSelection.catalogueIDs.count + 3)
        #expect(theme.selectedThemeId != nil)
        try await CisumKernelFixture.destroyKernel(kernel)
    }

    @Test
    func kernelLoadsOnlyWhitelistedCatalogueThemes() async throws {
        let kernel = try await CisumKernelFixture.makeKernel()
        let theme = try #require(kernel.resolveProvider((any ThemeProviding).self))

        let catalogueIDs = Set(CisumThemeSelection.catalogueIDs)
        let loaded = theme.themes.filter { catalogueIDs.contains($0.id) }
        #expect(Set(loaded.map(\.id)) == catalogueIDs)

        // 白名单外的目录主题不应出现在可选列表中。
        #expect(!theme.themes.contains { $0.id == "dracula" })
        #expect(!theme.themes.contains { $0.id == "github" })

        try await CisumKernelFixture.destroyKernel(kernel)
    }

    @Test
    func kernelExposesCloudDownloadProgressProvider() async throws {
        let kernel = try await CisumKernelFixture.makeKernel()
        let download = try #require(kernel.resolveProvider((any CloudDownloadProviding).self))

        // A plain local file is not iCloud-backed, so the provider must
        // report it as complete rather than as a pending download.
        #expect(download.progress(for: URL(fileURLWithPath: "/tmp")) == 1)

        try await CisumKernelFixture.destroyKernel(kernel)
    }

    @Test
    func kernelExposesSharedThemeSettingsNavigationItem() async throws {
        let kernel = try await CisumKernelFixture.makeKernel()
        let settings = try #require(kernel.resolveProvider((any SettingViewProviding).self))

        #expect(settings.entries.contains { $0.id == "appearance" })

        try await CisumKernelFixture.destroyKernel(kernel)
    }

    /// 插件管理器入口在完整装配后出现在设置导航中。
    ///
    /// 入口由插件管理器在 `onReady` 按「存在可配置插件」自动注册；
    /// 书库、视频库、欢迎页、仓库引导任一被误改回 `alwaysOn` 时，
    /// 这里会随入口消失一起失败。
    @Test
    func kernelExposesPluginManagerSettingsNavigationItem() async throws {
        let kernel = try await CisumKernelFixture.makeKernel()
        let settings = try #require(kernel.resolveProvider((any SettingViewProviding).self))

        #expect(settings.entries.contains { $0.id == "plugin-manager" })

        try await CisumKernelFixture.destroyKernel(kernel)
    }
}