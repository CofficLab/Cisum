import Foundation
import Testing
@testable import PluginOpenButton

@Test func pluginMetadataIsStable() {
    #expect(OpenButtonPluginInfo.toolbarItemId == "open-current")
    #expect(!OpenButtonPluginInfo.description.isEmpty)
    #expect(!OpenButtonPluginInfo.iconName.isEmpty)
    #expect(OpenCurrentButtonView.accessibilityTitle == "Show in Finder")
}

@Test func openCurrentButtonRequiresReachableLocalFile() {
    let fileURL = URL(fileURLWithPath: "/tmp/cisum-open-current.mp3")
    let missingFileURL = URL(fileURLWithPath: "/tmp/cisum-open-current-missing.mp3")
    let remoteURL = URL(string: "https://example.com/audio.mp3")!

    #expect(OpenCurrentButtonView.shouldShowOpenButton(for: fileURL) { path in
        path == fileURL.path
    })
    #expect(!OpenCurrentButtonView.shouldShowOpenButton(for: missingFileURL) { path in
        path == fileURL.path
    })
    #expect(!OpenCurrentButtonView.shouldShowOpenButton(for: remoteURL) { _ in
        true
    })
}
