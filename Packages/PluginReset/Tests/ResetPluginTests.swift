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
