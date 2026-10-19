import KernelCore
import ProviderPlugin
import Testing
@testable import PluginReset

@Test func pluginInfoExportsRegistrationMetadata() {
    #expect(ResetPluginInfo.iconName == "gearshape")
    #expect(ResetPluginInfo.emoji == "⚙️")
    #expect(ResetPluginInfo.order == 90)
}

@Test func resetSheetOnlyAllowsDismissBeforeResetStarts() {
    #expect(!ResetConfirm.shouldDisableInteractiveDismiss(isResetting: false))
    #expect(ResetConfirm.shouldDisableInteractiveDismiss(isResetting: true))
}

@Test func resetIconButtonsExposeReadableLabels() {
    #expect(SystemSetting.resetStorageLocationActionLabel == "Reset Storage Location")
    #expect(ResetConfirm.closeButtonLabel == "Close")
}

@MainActor
@Test func systemPluginExposesStableIdentityAndMetadata() {
    let plugin = SystemPlugin.shared

    #expect(plugin.id == "SystemPlugin")
    #expect(plugin.order == 90)
    #expect(plugin.iconName == "gearshape")
    #expect(plugin.metadata.id == "SystemPlugin")
    #expect(plugin.metadata.name == "System")
    #expect(plugin.metadata.version == "1.0.0")
    #expect(plugin.metadata.category == .system)
    #expect(plugin.metadata.stage == .stable)
    #expect(plugin.metadata.policy == .disabled)
    #expect(plugin.metadata.permissions.isEmpty)
}

// MARK: - 生命周期

/// 未注册任何 Provider 时，注册流程必须静默跳过而不是崩溃 ——
/// 插件的 onRegister 可能早于 Docs/Setting 等 Provider 就绪。
@MainActor
@Test func onRegisterWithoutAnyProviderIsSafe() async throws {
    let kernel = KernelCoreContainer()
    let plugin = SystemPlugin()
    try await plugin.onRegister(kernel: kernel)
    // 不崩溃即为通过
}

@MainActor
@Test func onBootWithoutSettingProviderIsSafe() async throws {
    let kernel = KernelCoreContainer()
    let plugin = SystemPlugin()
    try await plugin.onBoot(kernel: kernel)
    // 无 PluginContribution provider 时静默跳过
}

@MainActor
@Test func onBootWithContributionProviderAddsSettingEntry() async throws {
    let kernel = KernelCoreContainer()
    let contributions = PluginContributionService(kernel: kernel)
    try kernel.registerProvider((any PluginContributionProviding).self, contributions)

    let plugin = SystemPlugin()
    try await plugin.onBoot(kernel: kernel)

    // 设置项已生成，可重复生成且 id 稳定
    let first = plugin.makeSettingEntry()
    let second = plugin.makeSettingEntry()
    #expect(first?.id == "system")
    #expect(first?.id == second?.id)
    #expect(first?.order == ResetPluginInfo.order)
}

@MainActor
@Test func onShutdownIsIdempotentAndSafeWithoutProviders() async throws {
    let kernel = KernelCoreContainer()
    let plugin = SystemPlugin()
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onShutdown(kernel: kernel)
    // 重复 shutdown 不应崩溃
    try await plugin.onShutdown(kernel: kernel)
}

@MainActor
@Test func fullLifecycleRoundTripDoesNotCrash() async throws {
    let kernel = KernelCoreContainer()
    let contributions = PluginContributionService(kernel: kernel)
    try kernel.registerProvider((any PluginContributionProviding).self, contributions)

    let plugin = SystemPlugin()
    try await plugin.onRegister(kernel: kernel)
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onEnable(kernel: kernel)
    try await plugin.onDisable(kernel: kernel)
    try await plugin.onShutdown(kernel: kernel)
    #expect(plugin.makeSettingEntry() != nil)
}
