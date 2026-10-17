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
