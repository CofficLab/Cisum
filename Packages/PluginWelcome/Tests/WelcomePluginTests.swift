@testable import PluginWelcome
import Testing

@Test func pluginInfoExportsRegistrationMetadata() {
    #expect(WelcomePluginInfo.iconName == "hand.wave")
    #expect(WelcomePluginInfo.emoji == "👏")
    #expect(WelcomePluginInfo.order == -100)
}

@Test func storageSelectionDefaultsToICloudWhenAvailable() {
    #expect(WelcomeStorageSelectionPolicy.defaultSelection(
        currentStorageSelection: nil,
        isICloudAvailable: true
    ) == .icloud)
    #expect(WelcomeStorageSelectionPolicy.displayedSelection(
        currentStorageSelection: nil,
        isICloudAvailable: true
    ) == .icloud)
}

@Test func storageSelectionFallsBackToLocalWhenICloudUnavailable() {
    #expect(WelcomeStorageSelectionPolicy.defaultSelection(
        currentStorageSelection: .icloud,
        isICloudAvailable: false
    ) == .local)
    #expect(WelcomeStorageSelectionPolicy.validatedSelection(
        .icloud,
        isICloudAvailable: false
    ) == .local)
    #expect(WelcomeStorageSelectionPolicy.displayedSelection(
        currentStorageSelection: .icloud,
        isICloudAvailable: false
    ) == .local)
}

@Test func storageSelectionDisplaysLocalWhenItIsTheOnlyAvailableOption() {
    #expect(WelcomeStorageSelectionPolicy.displayedSelection(
        currentStorageSelection: nil,
        isICloudAvailable: false
    ) == .local)
    #expect(WelcomeStorageSelectionPolicy.defaultSelection(
        currentStorageSelection: nil,
        isICloudAvailable: false
    ) == .local)
}

@Test func storageSelectionDoesNotPersistInitialDefaultBeforeUserChooses() {
    #expect(!WelcomeStorageSelectionPolicy.shouldPersistDisplayedSelectionOnAppear(
        currentStorageSelection: nil,
        displayedSelection: .icloud
    ))
    #expect(!WelcomeStorageSelectionPolicy.shouldPersistDisplayedSelectionOnAppear(
        currentStorageSelection: nil,
        displayedSelection: .local
    ))
}

@Test func storageSelectionPersistsOnlyExistingUnavailableSelectionFallback() {
    #expect(WelcomeStorageSelectionPolicy.shouldPersistDisplayedSelectionOnAppear(
        currentStorageSelection: .icloud,
        displayedSelection: .local
    ))
    #expect(!WelcomeStorageSelectionPolicy.shouldPersistDisplayedSelectionOnAppear(
        currentStorageSelection: .local,
        displayedSelection: .local
    ))
}

@Test func storageSelectionDoesNotPersistInitialDefaultOnDisappear() {
    #expect(!WelcomeStorageSelectionPolicy.shouldPersistDisplayedSelectionOnDisappear(
        currentStorageSelection: nil,
        displayedSelection: .icloud
    ))
    #expect(!WelcomeStorageSelectionPolicy.shouldPersistDisplayedSelectionOnDisappear(
        currentStorageSelection: nil,
        displayedSelection: .local
    ))
    #expect(WelcomeStorageSelectionPolicy.shouldPersistDisplayedSelectionOnDisappear(
        currentStorageSelection: .icloud,
        displayedSelection: .local
    ))
}

@Test @MainActor func completingWelcomeGuidePersistsDisplayedDefaultSelection() {
    var storedSelection: WelcomeStorageSelection?

    WelcomePluginHost.configure(
        hasStorageLocation: {
            storedSelection != nil
        },
        isICloudAvailable: {
            true
        },
        currentStorageSelection: {
            storedSelection
        },
        updateStorageSelection: { selection in
            storedSelection = selection
        }
    )

    #expect(WelcomePlugin.shared.completeGuidePage())
    #expect(storedSelection == .icloud)

    storedSelection = nil

    WelcomePluginHost.configure(
        hasStorageLocation: {
            storedSelection != nil
        },
        isICloudAvailable: {
            false
        },
        currentStorageSelection: {
            storedSelection
        },
        updateStorageSelection: { selection in
            storedSelection = selection
        }
    )

    #expect(WelcomePlugin.shared.completeGuidePage())
    #expect(storedSelection == .local)
}

@Test @MainActor
func guideViewIsShownOnlyWhenNoStorageLocationExists() {
    var hasLocation = false
    WelcomePluginHost.configure(
        hasStorageLocation: { hasLocation },
        isICloudAvailable: { true },
        currentStorageSelection: { nil },
        updateStorageSelection: { _ in }
    )

    #expect(WelcomePlugin.shared.addGuideView() != nil)

    hasLocation = true
    #expect(WelcomePlugin.shared.addGuideView() == nil)
}

@Test @MainActor
func completingGuideWhenStorageExistsSkipsUpdate() {
    var updated = false
    WelcomePluginHost.configure(
        hasStorageLocation: { true },
        isICloudAvailable: { true },
        currentStorageSelection: { .icloud },
        updateStorageSelection: { _ in updated = true }
    )

    #expect(WelcomePlugin.shared.completeGuidePage())
    #expect(!updated)
}

@Test @MainActor
func hostForwardsUpdateStorageSelection() {
    var received: WelcomeStorageSelection?
    WelcomePluginHost.configure(
        hasStorageLocation: { false },
        isICloudAvailable: { false },
        currentStorageSelection: { nil },
        updateStorageSelection: { received = $0 }
    )

    WelcomePluginHost.updateStorageSelection(.local)
    #expect(received == .local)
    #expect(WelcomePluginHost.hasStorageLocation == false)
    #expect(WelcomePluginHost.isICloudAvailable == false)
}
