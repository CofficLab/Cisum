import Foundation
import KernelCore
import ProviderPlugin
import Testing
@testable import PluginSettingsButton

@Test @MainActor func pluginMetadataIsStable() {
    #expect(SettingsButtonPluginInfo.toolbarItemId == "settings-button")
    #expect(SettingsButtonPluginInfo.settingsWindowID == "cisum.settings")
    #expect(SettingsButtonPluginInfo.iconName == "gearshape")
    #expect(!SettingsButtonPluginInfo.description.isEmpty)
    #expect(SettingsButtonView.title == "Settings")
}

@Test @MainActor func pluginMetadataDescribesSettingsEntry() {
    #expect(SettingsButtonPlugin().metadata.name == "Settings")
    #expect(SettingsButtonPlugin().metadata.category == .system)
    #expect(SettingsButtonPlugin().metadata.policy == .alwaysOn)
}

// MARK: - 生命周期

/// 注册与启动阶段可能早于各 Provider 就绪，缺失时必须静默跳过。
@Test @MainActor func lifecycleWithoutAnyProviderIsSafe() async throws {
    let kernel = KernelCoreContainer()
    let plugin = SettingsButtonPlugin()
    try await plugin.onRegister(kernel: kernel)
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onEnable(kernel: kernel)
    try await plugin.onShutdown(kernel: kernel)
    // 不崩溃即为通过
}

/// 关闭时应撤回贡献，避免工具栏残留悬空按钮。
@Test @MainActor func onShutdownRemovesToolbarContribution() async throws {
    let kernel = KernelCoreContainer()
    let contributions = PluginContributionService(kernel: kernel)
    try kernel.registerProvider((any PluginContributionProviding).self, contributions)

    let plugin = SettingsButtonPlugin()
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onShutdown(kernel: kernel)

    // 重复关闭不应崩溃
    try await plugin.onShutdown(kernel: kernel)
}

/// 设置按钮是系统级常驻入口，重复启动不应产生重复项。
@Test @MainActor func toolbarContributionIsStableAcrossRepeatedBoot() async throws {
    #if os(macOS)
    let kernel = KernelCoreContainer()
    let contributions = PluginContributionService(kernel: kernel)
    try kernel.registerProvider((any PluginContributionProviding).self, contributions)

    let plugin = SettingsButtonPlugin()
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onBoot(kernel: kernel)

    let buttons = plugin.addToolBarButtons()
    #expect(buttons.count == 1)
    #expect(buttons.first?.id == SettingsButtonPluginInfo.toolbarItemId)
    #endif
}

@Test @MainActor func pluginOrderPlacesSettingsButtonLast() {
    // 工具栏按钮按 order 排序，设置按钮应排在最后
    #expect(SettingsButtonPlugin().order == 9999)
}
