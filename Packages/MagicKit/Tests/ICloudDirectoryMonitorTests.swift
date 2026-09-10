import Foundation
import Testing

@testable import MagicKit

@Test func iCloudDirectoryMonitorLifecycleSuppressesCancelledDelayedStart() {
    let lifecycle = ICloudDirectoryMonitorLifecycle()
    let cancelledRun = lifecycle.beginRun()

    #expect(lifecycle.shouldStart(runID: cancelledRun))
    #expect(lifecycle.cancel(runID: cancelledRun))
    #expect(!lifecycle.shouldStart(runID: cancelledRun))
}

@Test func iCloudDirectoryMonitorLifecycleKeepsReplacementRunAfterStaleCancel() {
    let lifecycle = ICloudDirectoryMonitorLifecycle()
    let staleRun = lifecycle.beginRun()
    let replacementRun = lifecycle.beginRun()

    #expect(!lifecycle.cancel(runID: staleRun))
    #expect(!lifecycle.shouldStart(runID: staleRun))
    #expect(lifecycle.shouldStart(runID: replacementRun))
}

@Test func iCloudDirectoryMonitorDirectScanEnumeratesNestedPlaceholderLikeFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("cisum-icloud-monitor-\(UUID().uuidString)", isDirectory: true)
    let nested = root.appendingPathComponent("book", isDirectory: true)
    let audio = nested.appendingPathComponent("chapter.mp3")
    defer { try? FileManager.default.removeItem(at: root) }

    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try Data("placeholder metadata".utf8).write(to: audio)

    let urls = try ICloudDirectoryMonitor.scanDirectoryContents(at: root)
    let identities = Set(urls.map { $0.resolvingSymlinksInPath().standardizedFileURL.path })

    #expect(identities.contains(nested.resolvingSymlinksInPath().standardizedFileURL.path))
    #expect(identities.contains(audio.resolvingSymlinksInPath().standardizedFileURL.path))
}
