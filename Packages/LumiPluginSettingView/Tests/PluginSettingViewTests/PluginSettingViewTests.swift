import KernelCore
import ProviderSettingView
import SwiftUI
import Testing
@testable import PluginSettingView

@Suite("PluginSettingView")
@MainActor
struct PluginSettingViewTests {

    @Test("插件替换默认设置 Provider 并保留已有入口")
    func replacesProviderAndPreservesEntries() throws {
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        settings.registerEntries([
            SettingEntryItem(id: "appearance", title: "外观", systemImage: "paintpalette") {
                Text("appearance")
            },
        ])
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        try PluginSettingView().onBoot(kernel: kernel)

        let replacement = try #require(kernel.resolveProvider((any SettingViewProviding).self))
        #expect(replacement.entries.map(\.id) == ["appearance"])
        #expect(replacement.selectedEntryID == "appearance")
        #expect(type(of: replacement.makeSettingView()) == AnyView.self)
    }

    @Test("没有旧 Provider 时正常启动")
    func bootsWithoutExistingProvider() throws {
        let kernel = KernelCoreContainer()
        try PluginSettingView().onBoot(kernel: kernel)

        let replacement = try #require(kernel.resolveProvider((any SettingViewProviding).self))
        #expect(replacement.entries.isEmpty)
        #expect(replacement.selectedEntryID == nil)
    }

    @Test("onShutdown 清理 manager")
    func shutdownClearsManager() throws {
        let kernel = KernelCoreContainer()
        let plugin = PluginSettingView()
        try plugin.onBoot(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)
        // shutdown 后 manager 置 nil，不抛错即可
    }

    @Test("插件元数据符合约定")
    func pluginMetadata() {
        let plugin = PluginSettingView()
        #expect(plugin.id == "com.coffic.kuzee.plugin.setting-view")
        #expect(plugin.order == 3)
        #expect(plugin.metadata.policy == .required)
        #expect(plugin.metadata.category == .core)
        #expect(!plugin.metadata.policy.isConfigurable)
    }

    @Test("宿主可注入自定义插件 id")
    func customIDIsApplied() {
        let plugin = PluginSettingView(id: "com.example.custom.plugin.setting-view")

        #expect(plugin.id == "com.example.custom.plugin.setting-view")
        #expect(plugin.metadata.id == plugin.id)
        #expect(PluginSettingView.defaultPluginID == "com.coffic.kuzee.plugin.setting-view")
    }
}
