import Testing
@testable import PluginAudio

@Test func missingStorageErrorKeepsStorageSetupGuidance() {
    let presentation = AudioRootErrorPresentation.make(error: .storageMissing)

    #expect(presentation.title == "Storage Location Not Set")
    #expect(presentation.message == "Set the media library storage location first.")
    #expect(presentation.detail == nil)
}

@Test func databaseInitializationErrorShowsActualFailure() {
    let presentation = AudioRootErrorPresentation.make(error: .initialization("database is locked"))

    #expect(presentation.title == "Audio Library Initialization Failed")
    #expect(presentation.message == "Try reopening the app or checking media library settings.")
    #expect(presentation.detail == "database is locked")
}
