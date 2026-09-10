import Foundation
import PluginAudioJob
import Testing

private final class RecordingAudioJob: AudioJob, @unchecked Sendable {
    nonisolated let identifier: String
    nonisolated let name: String
    nonisolated let description: String

    private let state = State()

    init(identifier: String) {
        self.identifier = identifier
        self.name = identifier
        self.description = identifier
    }

    func execute() async throws {
        await state.markStarted()

        while await state.isRunning {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func cancel() {
        Task {
            await state.cancel()
        }
    }

    func startCount() async -> Int {
        await state.startCount
    }

    func cancelCount() async -> Int {
        await state.cancelCount
    }

    private actor State {
        var isRunning = true
        var startCount = 0
        var cancelCount = 0

        func markStarted() {
            startCount += 1
        }

        func cancel() {
            cancelCount += 1
            isRunning = false
        }
    }
}

@Test func jobStatusExportsMetadata() {
    let status = JobStatus(identifier: "job", name: "Job", isRunning: true)

    #expect(status.identifier == "job")
    #expect(status.name == "Job")
    #expect(status.isRunning)
}

@Test func audioJobPluginIsAlwaysOnForLibrarySynchronization() {
    #expect(AudioJobPlugin.metadata.policy == .alwaysOn)
}

@Test func localFileChangesUseFullSync() {
    let localDisk = URL(fileURLWithPath: "/tmp/cisum-audio-job-tests", isDirectory: true)

    #expect(FileSystemMonitorJob.shouldPerformFullSync(isFirst: true, disk: nil))
    #expect(FileSystemMonitorJob.shouldPerformFullSync(isFirst: false, disk: localDisk))
}

@Test func staleMonitorRunStopsAfterRestart() {
    let firstRun = UUID()
    let secondRun = UUID()

    #expect(FileSystemMonitorJob.shouldContinueRunning(
        runID: firstRun,
        activeRunID: firstRun,
        isRunning: true
    ))
    #expect(!FileSystemMonitorJob.shouldContinueRunning(
        runID: firstRun,
        activeRunID: secondRun,
        isRunning: true
    ))
    #expect(!FileSystemMonitorJob.shouldContinueRunning(
        runID: firstRun,
        activeRunID: nil,
        isRunning: false
    ))
}

@Test func staleMonitorEventsAreIgnoredAfterRestart() {
    let firstRun = UUID()
    let secondRun = UUID()

    #expect(FileSystemMonitorJob.shouldProcessMonitorEvent(
        runID: firstRun,
        activeRunID: firstRun,
        isRunning: true
    ))
    #expect(!FileSystemMonitorJob.shouldProcessMonitorEvent(
        runID: firstRun,
        activeRunID: secondRun,
        isRunning: true
    ))
    #expect(!FileSystemMonitorJob.shouldProcessMonitorEvent(
        runID: firstRun,
        activeRunID: nil,
        isRunning: false
    ))
}

@Test func monitorScanErrorsDoNotSyncEmptyResults() {
    let error = NSError(domain: "FileSystemMonitorJobTests", code: 1)

    #expect(FileSystemMonitorJob.shouldSyncMonitorItems(error: nil))
    #expect(!FileSystemMonitorJob.shouldSyncMonitorItems(error: error))
}

@Test func staleMonitorCancellationDoesNotStopReplacementRun() {
    let firstRun = UUID()
    let secondRun = UUID()

    #expect(FileSystemMonitorJob.shouldApplyCancellation(
        cancelledRunID: firstRun,
        activeRunID: firstRun
    ))
    #expect(!FileSystemMonitorJob.shouldApplyCancellation(
        cancelledRunID: firstRun,
        activeRunID: secondRun
    ))
    #expect(FileSystemMonitorJob.shouldApplyCancellation(
        cancelledRunID: nil,
        activeRunID: secondRun
    ))
}

@Test func unregisterCancelsRunningJob() async throws {
    let manager = AudioJobManager.shared
    let identifier = "test.unregister.\(UUID().uuidString)"
    let job = RecordingAudioJob(identifier: identifier)

    await manager.register(job)
    await manager.startJob(identifier)
    try await waitUntil { await job.startCount() == 1 }

    await manager.unregister(identifier)

    try await waitUntil { await job.cancelCount() == 1 }
    #expect(await manager.getJobStatus(identifier) == nil)
}

@Test func registeringReplacementCancelsRunningJobWithSameIdentifier() async throws {
    let manager = AudioJobManager.shared
    let identifier = "test.replace.\(UUID().uuidString)"
    let firstJob = RecordingAudioJob(identifier: identifier)
    let replacementJob = RecordingAudioJob(identifier: identifier)

    await manager.register(firstJob)
    await manager.startJob(identifier)
    try await waitUntil { await firstJob.startCount() == 1 }

    await manager.register(replacementJob)
    await manager.startJob(identifier)
    try await waitUntil { await firstJob.cancelCount() == 1 }
    try await waitUntil { await replacementJob.startCount() == 1 }

    await manager.unregister(identifier)
    try await waitUntil { await replacementJob.cancelCount() == 1 }
}

private func waitUntil(
    timeout: Duration = .seconds(1),
    condition: @escaping () async -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout

    while clock.now < deadline {
        if await condition() {
            return
        }

        try await Task.sleep(nanoseconds: 10_000_000)
    }

    Issue.record("Timed out waiting for condition")
}
