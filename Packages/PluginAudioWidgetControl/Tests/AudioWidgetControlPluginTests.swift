import Foundation
import Testing
@testable import PluginAudioWidgetControl

@Test func pluginMetadataIsStable() {
    #expect(AudioWidgetControlPluginInfo.iconName == "command")
    #expect(!AudioWidgetControlPluginInfo.title.isEmpty)
    #expect(!AudioWidgetControlPluginInfo.description.isEmpty)
}

@Test func navigationResultOnlyAppliesToUnchangedCurrentAsset() {
    let requested = URL(fileURLWithPath: "/tmp/requested.mp3")
    let switched = URL(fileURLWithPath: "/tmp/switched.mp3")

    #expect(AudioWidgetPlaybackRequestPolicy.shouldApplyNavigationResult(
        requestedAsset: requested,
        currentAsset: requested
    ))
    #expect(!AudioWidgetPlaybackRequestPolicy.shouldApplyNavigationResult(
        requestedAsset: requested,
        currentAsset: switched
    ))
    #expect(!AudioWidgetPlaybackRequestPolicy.shouldApplyNavigationResult(
        requestedAsset: requested,
        currentAsset: nil
    ))
}

@Test func navigationResultAppliesToSymlinkedCurrentAsset() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realFile = root.appendingPathComponent("real.mp3")
    let linkedFile = root.appendingPathComponent("linked.mp3")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: realFile)
    try FileManager.default.createSymbolicLink(at: linkedFile, withDestinationURL: realFile)

    #expect(AudioWidgetPlaybackRequestPolicy.shouldApplyNavigationResult(
        requestedAsset: linkedFile,
        currentAsset: realFile
    ))
}

@Test func navigationResultDoesNotApplyToDistinctDanglingSymlinks() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let missingTrack = root.appendingPathComponent("missing.mp3")
    let firstLink = root.appendingPathComponent("first.mp3")
    let secondLink = root.appendingPathComponent("second.mp3")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: firstLink, withDestinationURL: missingTrack)
    try FileManager.default.createSymbolicLink(at: secondLink, withDestinationURL: missingTrack)

    #expect(!AudioWidgetPlaybackRequestPolicy.shouldApplyNavigationResult(
        requestedAsset: firstLink,
        currentAsset: secondLink
    ))
}

@Test func widgetNavigationWaitsForPreviousNavigationTask() {
    #expect(AudioWidgetPlaybackRequestPolicy.shouldWaitForPreviousNavigation(hasPreviousTask: true))
    #expect(!AudioWidgetPlaybackRequestPolicy.shouldWaitForPreviousNavigation(hasPreviousTask: false))
}

@Test func widgetCommandCountPreservesRapidRepeatedCommands() {
    #expect(AudioWidgetPlaybackRequestPolicy.commandCount(from: 3) == 3)
    #expect(AudioWidgetPlaybackRequestPolicy.commandCount(from: NSNumber(value: 3)) == 3)
    #expect(AudioWidgetPlaybackRequestPolicy.commandCount(from: 0) == 0)
    #expect(AudioWidgetPlaybackRequestPolicy.commandCount(from: -2) == 0)
    #expect(AudioWidgetPlaybackRequestPolicy.commandCount(from: 99) == 10)
}

@Test func widgetCommandCountAcceptsLegacyTimestampTrigger() {
    #expect(AudioWidgetPlaybackRequestPolicy.commandCount(from: TimeInterval(1_700_000_000)) == 1)
    #expect(AudioWidgetPlaybackRequestPolicy.commandCount(from: NSNumber(value: 1_700_000_000.0)) == 1)
    #expect(AudioWidgetPlaybackRequestPolicy.commandCount(from: nil) == 0)
    #expect(AudioWidgetPlaybackRequestPolicy.commandCount(from: "unexpected") == 0)
}

@Test func widgetCommandConsumptionPreservesCommandsAddedDuringHandling() {
    #expect(AudioWidgetPlaybackRequestPolicy.remainingCommandCount(
        afterConsuming: 1,
        storedValue: NSNumber(value: 1)
    ) == 0)
    #expect(AudioWidgetPlaybackRequestPolicy.remainingCommandCount(
        afterConsuming: 1,
        storedValue: NSNumber(value: 2)
    ) == 1)
    #expect(AudioWidgetPlaybackRequestPolicy.remainingCommandCount(
        afterConsuming: 3,
        storedValue: NSNumber(value: 2)
    ) == 0)
}

@Test func widgetPlayPauseCommandTogglesOnlyOddRepeatedCommands() {
    #expect(AudioWidgetPlaybackRequestPolicy.playPauseAction(
        currentState: .playing,
        commandCount: 1
    ) == .pause)
    #expect(AudioWidgetPlaybackRequestPolicy.playPauseAction(
        currentState: .paused,
        commandCount: 1
    ) == .play)
    #expect(AudioWidgetPlaybackRequestPolicy.playPauseAction(
        currentState: .playing,
        commandCount: 2
    ) == nil)
    #expect(AudioWidgetPlaybackRequestPolicy.playPauseAction(
        currentState: .paused,
        commandCount: 4
    ) == nil)
}
