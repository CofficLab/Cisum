import Foundation
import Testing
@testable import PluginAudioDBData

@Test func audioDatabasePluginIsAlwaysOnForLibrarySynchronization() {
    #expect(AudioDBDataPlugin.metadata.policy == .alwaysOn)
}

@Test func localFileChangesUseFullSync() {
    let localDisk = URL(fileURLWithPath: "/tmp/cisum-audio-db-sync-tests", isDirectory: true)

    #expect(AudioFileSystemMonitor.shouldPerformFullSync(isFirst: true, disk: nil))
    #expect(AudioFileSystemMonitor.shouldPerformFullSync(isFirst: false, disk: localDisk))
}

@Test func staleMonitorRunStopsAfterRestart() {
    let firstRun = UUID()
    let secondRun = UUID()

    #expect(AudioFileSystemMonitor.shouldContinueRunning(
        runID: firstRun,
        activeRunID: firstRun,
        isRunning: true
    ))
    #expect(!AudioFileSystemMonitor.shouldContinueRunning(
        runID: firstRun,
        activeRunID: secondRun,
        isRunning: true
    ))
    #expect(!AudioFileSystemMonitor.shouldContinueRunning(
        runID: firstRun,
        activeRunID: nil,
        isRunning: false
    ))
}

@Test func staleMonitorEventsAreIgnoredAfterRestart() {
    let firstRun = UUID()
    let secondRun = UUID()

    #expect(AudioFileSystemMonitor.shouldProcessMonitorEvent(
        runID: firstRun,
        activeRunID: firstRun,
        isRunning: true
    ))
    #expect(!AudioFileSystemMonitor.shouldProcessMonitorEvent(
        runID: firstRun,
        activeRunID: secondRun,
        isRunning: true
    ))
    #expect(!AudioFileSystemMonitor.shouldProcessMonitorEvent(
        runID: firstRun,
        activeRunID: nil,
        isRunning: false
    ))
}

@Test func monitorScanErrorsDoNotSyncEmptyResults() {
    let error = NSError(domain: "AudioFileSystemMonitorTests", code: 1)

    #expect(AudioFileSystemMonitor.shouldSyncMonitorItems(error: nil))
    #expect(!AudioFileSystemMonitor.shouldSyncMonitorItems(error: error))
}

@Test func staleMonitorCancellationDoesNotStopReplacementRun() {
    let firstRun = UUID()
    let secondRun = UUID()

    #expect(AudioFileSystemMonitor.shouldApplyCancellation(
        cancelledRunID: firstRun,
        activeRunID: firstRun
    ))
    #expect(!AudioFileSystemMonitor.shouldApplyCancellation(
        cancelledRunID: firstRun,
        activeRunID: secondRun
    ))
    #expect(AudioFileSystemMonitor.shouldApplyCancellation(
        cancelledRunID: nil,
        activeRunID: secondRun
    ))
}
