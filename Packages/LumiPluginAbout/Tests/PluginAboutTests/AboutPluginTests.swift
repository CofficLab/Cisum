import Foundation
import KernelCore
import ProviderSettingView
import Testing
@testable import PluginAbout

/// 插件入口的生命周期测试：注册、撤回、品牌 id 注入、官网配置。
@MainActor
struct AboutPluginTests {
    /// 测试用的宿主配置。
    private static var configuration: AboutConfiguration {
        AboutConfiguration(
            officialWebsiteURLString: "https://coffic.cn/cisum",
            privacyPolicyURLString: "https://coffic.cn/privacy",
            termsOfServiceURLString: "https://coffic.cn/terms"
        )
    }

    /// 启动时必须把「关于」入口登记到设置 Provider 上。
    @Test
    func bootRegistersSettingsEntry() throws {
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = AboutPlugin(configuration: Self.configuration)
        try plugin.onBoot(kernel: kernel)

        let entry = try #require(settings.entries.first { $0.id == AboutPlugin.settingsEntryID })
        #expect(entry.systemImage == "info.circle")
        #expect(entry.id == "about")
    }

    /// 关闭时必须撤回入口——否则设置窗口里会留下一个点不动的入口。
    @Test
    func shutdownRemovesSettingsEntry() throws {
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = AboutPlugin(configuration: Self.configuration)
        try plugin.onBoot(kernel: kernel)
        #expect(settings.entries.contains { $0.id == AboutPlugin.settingsEntryID })

        try plugin.onShutdown(kernel: kernel)
        #expect(!settings.entries.contains { $0.id == AboutPlugin.settingsEntryID })
    }

    /// 宿主注入品牌 id 后，插件 id 与元信息 id 同步跟随。
    @Test
    func hostCanInjectBrandID() {
        let plugin = AboutPlugin(id: "com.coffic.cisum.plugin.about", configuration: Self.configuration)
        #expect(plugin.id == "com.coffic.cisum.plugin.about")
        #expect(plugin.metadata.id == "com.coffic.cisum.plugin.about")
    }

    /// 默认 id 供未注入品牌的宿主使用。
    @Test
    func defaultIDIsUsedWhenNoBrandInjected() {
        let plugin = AboutPlugin(configuration: Self.configuration)
        #expect(plugin.id == AboutPlugin.defaultPluginID)
        #expect(plugin.metadata.id == AboutPlugin.defaultPluginID)
    }

    /// 设置入口 id 与品牌无关：深链地址在所有宿主里保持一致。
    @Test
    func settingsEntryIDIsBrandIndependent() {
        #expect(AboutPlugin.settingsEntryID == "about")
    }

    /// 宿主官网由宿主注入——插件无从推断，必须能被装配层覆盖。
    @Test
    func hostCanInjectOfficialWebsite() {
        let configuration = AboutConfiguration(officialWebsiteURLString: "https://coffic.cn/wakey")
        let plugin = AboutPlugin(configuration: configuration)
        #expect(plugin.configuration.officialWebsiteURLString == "https://coffic.cn/wakey")
    }

    /// 宿主没注入法律链接时，对应字段为 nil（页面据此隐藏该行）。
    @Test
    func legalLinksAreOptional() {
        let configuration = AboutConfiguration(officialWebsiteURLString: "https://coffic.cn/lumi")
        #expect(configuration.privacyPolicyURLString == nil)
        #expect(configuration.termsOfServiceURLString == nil)
    }

    /// 宿主没有注册设置 Provider 时优雅降级，不应抛错。
    @Test
    func bootWithoutSettingsProviderDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let plugin = AboutPlugin(configuration: Self.configuration)
        try plugin.onBoot(kernel: kernel)
    }

    /// 禁用策略会写进元信息，宿主据此让内核彻底排除插件。
    @Test
    func policyIsReflectedInMetadata() {
        let plugin = AboutPlugin(configuration: Self.configuration, policy: .disabled)
        #expect(plugin.metadata.policy == .disabled)
        #expect(plugin.policy == .disabled)
    }
}
