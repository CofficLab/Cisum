import Foundation
@testable import PluginBookSettings
import Testing

@Test func pluginInfoExportsRegistrationMetadata() {
    #expect(BookSettingsPluginInfo.iconName == "gearshape")
    #expect(BookSettingsPluginInfo.order == 11)
}

@Test func bookSettingsOnlyAppliesCurrentDiskMetrics() {
    let firstDisk = URL(fileURLWithPath: "/tmp/cisum-book-settings/first", isDirectory: true)
    let secondDisk = URL(fileURLWithPath: "/tmp/cisum-book-settings/second", isDirectory: true)

    #expect(BookSettingsMetricsPolicy.shouldApplyMetrics(
        currentDisk: firstDisk,
        requestedDisk: firstDisk,
        currentGeneration: 2,
        resultGeneration: 2
    ))
    #expect(!BookSettingsMetricsPolicy.shouldApplyMetrics(
        currentDisk: secondDisk,
        requestedDisk: firstDisk,
        currentGeneration: 2,
        resultGeneration: 2
    ))
    #expect(!BookSettingsMetricsPolicy.shouldApplyMetrics(
        currentDisk: firstDisk,
        requestedDisk: firstDisk,
        currentGeneration: 2,
        resultGeneration: 1
    ))
    #expect(!BookSettingsMetricsPolicy.shouldApplyMetrics(
        currentDisk: nil,
        requestedDisk: firstDisk,
        currentGeneration: 2,
        resultGeneration: 2
    ))
}

@Test func bookSettingsHidesOpenLibraryActionForMissingLocalDisk() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let missingDisk = root.appendingPathComponent("missing", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    #expect(!BookSettingsView.shouldShowOpenLibraryAction(for: missingDisk))
    #expect(BookSettingsView.shouldShowOpenLibraryAction(for: root))
}

@Test func bookSettingsUsesSingularFileCountOnlyForOneFile() {
    #expect(!BookSettingsView.shouldUseSingularFileCount(0))
    #expect(BookSettingsView.shouldUseSingularFileCount(1))
    #expect(!BookSettingsView.shouldUseSingularFileCount(2))
}
