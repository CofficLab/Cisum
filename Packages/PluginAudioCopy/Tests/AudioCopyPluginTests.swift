import Foundation
import SwiftData
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import PluginAudioCopy

@Test func audioCopyInfoExportsMetadata() {
    #expect(AudioCopyPluginInfo.iconName == "music.note")
}

#if os(macOS)
@MainActor
@Test func copyTaskCountNotificationPostsSynchronouslyOnMainThread() {
    let receivedCount = TestNotificationValue<Int?>(nil)
    let token = NotificationCenter.default.addObserver(
        forName: .copyTaskCountChanged,
        object: nil,
        queue: nil
    ) { notification in
        receivedCount.set(notification.userInfo?["count"] as? Int)
    }
    defer { NotificationCenter.default.removeObserver(token) }

    NotificationCenter.postCopyTaskCountChanged(count: 3)

    #expect(receivedCount.value == 3)
}

@Test func copyDropAcceptsOnlySupportedAudioFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let supportedAudio = root.appendingPathComponent("song.MP3")
    let unsupportedFile = root.appendingPathComponent("notes.txt")
    let folder = root.appendingPathComponent("album", isDirectory: true)

    try Data("audio".utf8).write(to: supportedAudio)
    try Data("notes".utf8).write(to: unsupportedFile)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

    #expect(CopyRootView<EmptyView>.isSupportedAudioFile(supportedAudio))
    #expect(!CopyRootView<EmptyView>.isSupportedAudioFile(unsupportedFile))
    #expect(!CopyRootView<EmptyView>.isSupportedAudioFile(folder))
}

@Test func copyDropDeduplicatesSymlinkedAudioSources() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let realFile = root.appendingPathComponent("real.mp3")
    let linkedFile = root.appendingPathComponent("linked.mp3")
    let unsupported = root.appendingPathComponent("notes.txt")
    try Data("audio".utf8).write(to: realFile)
    try Data("notes".utf8).write(to: unsupported)
    try FileManager.default.createSymbolicLink(at: linkedFile, withDestinationURL: realFile)

    #expect(CopyRootView<EmptyView>.representsSameCopySource(realFile, linkedFile))
    #expect(CopyRootView<EmptyView>.canonicalCopySourceIdentity(for: realFile) == CopyRootView<EmptyView>.canonicalCopySourceIdentity(for: linkedFile))
    #expect(CopyRootView<EmptyView>.uniqueSupportedAudioSources([
        linkedFile,
        unsupported,
        realFile,
    ]) == [linkedFile])
    #expect(CopyRootView<EmptyView>.shouldReportSkippedUnsupportedSources(
        [linkedFile, unsupported, realFile],
        sourceURLs: [linkedFile]
    ))
    #expect(!CopyRootView<EmptyView>.shouldReportSkippedUnsupportedSources(
        [linkedFile],
        sourceURLs: [linkedFile]
    ))
    #expect(!CopyRootView<EmptyView>.shouldReportSkippedUnsupportedSources(
        [unsupported],
        sourceURLs: []
    ))
}

@Test func copyDropKeepsDistinctDanglingSymlinkAudioSources() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let missingFile = root.appendingPathComponent("missing.mp3")
    let firstLink = root.appendingPathComponent("first.mp3")
    let secondLink = root.appendingPathComponent("second.mp3")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: firstLink, withDestinationURL: missingFile)
    try FileManager.default.createSymbolicLink(at: secondLink, withDestinationURL: missingFile)

    #expect(!CopyRootView<EmptyView>.representsSameCopySource(firstLink, secondLink))
    #expect(CopyRootView<EmptyView>.uniqueSupportedAudioSources([
        firstLink,
        secondLink,
    ]) == [firstLink, secondLink])
}

@Test func copyDropReadsFileURLDataProvider() async throws {
    let expected = URL(fileURLWithPath: "/tmp/cisum-copy-drop-provider-tests/track.mp3")
    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { completion in
        completion(expected.dataRepresentation, nil)
        return nil
    }

    let url = try await CopyRootView<EmptyView>.droppedFileURL(from: provider)

    #expect(url == expected)
}

@Test func copyDropReadsURLObjectProviderFallback() async throws {
    let expected = URL(fileURLWithPath: "/tmp/cisum-copy-drop-provider-tests/track.mp3")
    let provider = NSItemProvider(object: expected as NSURL)

    let url = try await CopyRootView<EmptyView>.droppedFileURL(from: provider)

    #expect(url == expected)
}

@Test func copyDropFallsBackToURLObjectAfterInvalidFileURLData() async throws {
    let expected = URL(fileURLWithPath: "/tmp/cisum-copy-drop-provider-tests/track.mp3")
    let provider = NSItemProvider(object: expected as NSURL)
    provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { completion in
        completion(Data("not a file url".utf8), nil)
        return nil
    }

    let url = try await CopyRootView<EmptyView>.droppedFileURL(from: provider)

    #expect(url == expected)
}

@Test func copyDropFallsBackToURLObjectAfterFileURLDataError() async throws {
    let expected = URL(fileURLWithPath: "/tmp/cisum-copy-drop-provider-tests/track.mp3")
    let provider = NSItemProvider(object: expected as NSURL)
    let error = NSError(domain: "CopyDrop", code: 1)
    provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { completion in
        completion(nil, error)
        return nil
    }

    let url = try await CopyRootView<EmptyView>.droppedFileURL(from: provider)

    #expect(url == expected)
}

@Test func copyWorkerPlansUniqueDestinationNames() {
    let folder = URL(fileURLWithPath: "/tmp/cisum-audio-copy-tests", isDirectory: true)
    let existingPath = folder.appendingPathComponent("track.mp3").path
    let tasks = [
        CopyTaskDTO(bookmark: Data([0]), destination: folder, originalFilename: "track.mp3"),
        CopyTaskDTO(bookmark: Data([1]), destination: folder, originalFilename: "track.mp3"),
        CopyTaskDTO(bookmark: Data([2]), destination: folder, originalFilename: "chapter"),
        CopyTaskDTO(bookmark: Data([3]), destination: folder, originalFilename: "chapter"),
    ]

    let destinations = CopyWorker.makeUniqueDestinationURLs(for: tasks) { url in
        url.path == existingPath
    }

    #expect(destinations.map(\.lastPathComponent) == [
        "track 2.mp3",
        "track 3.mp3",
        "chapter",
        "chapter 2",
    ])
}

@Test func copyWorkerAvoidsDanglingSymlinkDestinationNames() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
        at: root.appendingPathComponent("track.mp3"),
        withDestinationURL: root.appendingPathComponent("missing.mp3")
    )

    let tasks = [
        CopyTaskDTO(bookmark: Data([0]), destination: root, originalFilename: "track.mp3"),
    ]

    let destinations = CopyWorker.makeUniqueDestinationURLs(for: tasks)

    #expect(destinations.map(\.lastPathComponent) == ["track 2.mp3"])
}

@Test func copyWorkerCopiesResolvedSymlinkTarget() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let external = root.appendingPathComponent("external", isDirectory: true)
    try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
    let realFile = external.appendingPathComponent("real.mp3")
    let linkedFile = root.appendingPathComponent("linked.mp3")
    try Data("audio".utf8).write(to: realFile)
    try FileManager.default.createSymbolicLink(at: linkedFile, withDestinationURL: realFile)

    #expect(CopyWorker.copySourceURL(for: linkedFile).standardizedFileURL == realFile.standardizedFileURL)
    #expect(CopyWorker.copySourceURL(for: realFile).standardizedFileURL == realFile.standardizedFileURL)
}

@Test func copyWorkerAcceptsReadableLocalSourcesWithoutSecurityScope() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let readableFile = root.appendingPathComponent("track.mp3")
    let missingFile = root.appendingPathComponent("missing.mp3")
    try Data("audio".utf8).write(to: readableFile)

    #expect(CopyWorker.hasCopySourceAccess(readableFile, securityScopeGranted: false))
    #expect(CopyWorker.hasCopySourceAccess(missingFile, securityScopeGranted: true))
    #expect(!CopyWorker.hasCopySourceAccess(missingFile, securityScopeGranted: false))
}

@Test func copyStateMessageDistinguishesPendingAndFailedTasks() {
    #expect(CopyStatePresentation.message(pendingCount: 2, failedCount: 0) == "Copying 2 files")
    #expect(CopyStatePresentation.message(pendingCount: 1, failedCount: 0) == "Copying 1 file")
    #expect(CopyStatePresentation.message(pendingCount: 0, failedCount: 1) == "1 copy task failed")
    #expect(CopyStatePresentation.message(pendingCount: 0, failedCount: 2) == "2 copy tasks failed")
    #expect(CopyStatePresentation.message(pendingCount: 2, failedCount: 1) == "Copying 2 files, 1 failed")
    #expect(CopyStatePresentation.message(pendingCount: 1, failedCount: 1) == "Copying 1 file, 1 failed")
    #expect(CopyStatePresentation.message(pendingCount: 0, failedCount: 0).isEmpty)
}

@Test func copyStateDetailsButtonLabelTracksPopoverState() {
    #expect(CopyStatePresentation.detailsButtonLabel(isShowing: false) == "Show copy details")
    #expect(CopyStatePresentation.detailsButtonLabel(isShowing: true) == "Hide copy details")
}

@MainActor @Test func copyListRejectsStaleDeleteOffsets() {
    let folder = URL(fileURLWithPath: "/tmp/cisum-audio-copy-tests", isDirectory: true)
    let tasks = [
        CopyTask(bookmark: Data([0]), destination: folder, originalFilename: "one.mp3"),
        CopyTask(bookmark: Data([1]), destination: folder, originalFilename: "two.mp3"),
    ]

    #expect(CopyList.tasksToDelete(from: IndexSet(integer: 1), in: tasks)?.map(\.originalFilename) == ["two.mp3"])
    #expect(CopyList.tasksToDelete(from: IndexSet(integer: 2), in: tasks) == nil)
}

@MainActor @Test func copyTaskMessageShowsQueuedRunningAndFailedStates() {
    let task = CopyTask(
        bookmark: Data([0]),
        destination: URL(fileURLWithPath: "/tmp/cisum-audio-copy-tests", isDirectory: true),
        originalFilename: "one.mp3"
    )

    #expect(task.message == "Waiting to Copy")

    task.isRunning = true
    #expect(task.message == "In Progress")

    task.isRunning = false
    task.error = "Permission denied"
    #expect(task.message == "Permission denied")
}

@Test func copyLimitCountsCurrentLibraryAndIncomingDrop() {
    #expect(AudioCopyLimitPolicy.allowedTaskCount(
        currentAudioCount: 99,
        pendingCopyTaskCount: 0,
        requestedTaskCount: 10,
        maxAudioCount: 100,
        isFreeVersion: true
    ) == 1)

    #expect(AudioCopyLimitPolicy.allowedTaskCount(
        currentAudioCount: 100,
        pendingCopyTaskCount: 0,
        requestedTaskCount: 10,
        maxAudioCount: 100,
        isFreeVersion: true
    ) == 0)

    #expect(AudioCopyLimitPolicy.allowedTaskCount(
        currentAudioCount: 100,
        pendingCopyTaskCount: 0,
        requestedTaskCount: 10,
        maxAudioCount: 100,
        isFreeVersion: false
    ) == 10)

    #expect(AudioCopyLimitPolicy.allowedTaskCount(
        currentAudioCount: 99,
        pendingCopyTaskCount: 1,
        requestedTaskCount: 10,
        maxAudioCount: 100,
        isFreeVersion: true
    ) == 0)

    #expect(AudioCopyLimitPolicy.allowedTaskCount(
        currentAudioCount: 90,
        pendingCopyTaskCount: 5,
        requestedTaskCount: 10,
        maxAudioCount: 100,
        isFreeVersion: true
    ) == 5)
}

@Test func copyDropSkipsNoFilesAlertAfterPreparationFailure() {
    let error = NSError(domain: "AudioCopyDrop", code: 1)

    #expect(CopyRootView<EmptyView>.shouldShowNoFilesAdded(taskCount: 0, preparationErrors: [error]) == false)
    #expect(CopyRootView<EmptyView>.shouldShowNoFilesAdded(taskCount: 0, preparationErrors: []) == true)
    #expect(CopyRootView<EmptyView>.shouldShowNoFilesAdded(taskCount: 1, preparationErrors: [error]) == false)
    #expect(CopyRootView<EmptyView>.shouldReportPreparationFailure(preparedCount: 0, preparationErrors: [error]))
    #expect(!CopyRootView<EmptyView>.shouldReportPreparationFailure(preparedCount: 1, preparationErrors: [error]))
    #expect(!CopyRootView<EmptyView>.shouldReportPreparationFailure(preparedCount: 0, preparationErrors: []))
    #expect(CopyRootView<EmptyView>.shouldReportPartialDroppedURLLoadFailure(
        sourceURLs: [URL(fileURLWithPath: "/tmp/cisum-audio-copy-tests/song.mp3")],
        errors: [error]
    ))
    #expect(!CopyRootView<EmptyView>.shouldReportPartialDroppedURLLoadFailure(sourceURLs: [], errors: [error]))
    #expect(!CopyRootView<EmptyView>.shouldReportPartialDroppedURLLoadFailure(
        sourceURLs: [URL(fileURLWithPath: "/tmp/cisum-audio-copy-tests/song.mp3")],
        errors: []
    ))
}

@Test func copyDropOnlyChecksCopyServicesAfterFindingSources() {
    #expect(CopyRootView<EmptyView>.shouldPrepareCopyInfrastructure(sourceCount: 1))
    #expect(!CopyRootView<EmptyView>.shouldPrepareCopyInfrastructure(sourceCount: 0))
}

@Test func copyWorkerOnlyPostsFinishedWhenQueueIsStillEmpty() {
    let folder = URL(fileURLWithPath: "/tmp/cisum-audio-copy-tests", isDirectory: true)
    let task = CopyTaskDTO(bookmark: Data([0]), destination: folder, originalFilename: "new.mp3")

    #expect(CopyWorker.shouldPostFinished(afterDelayRemainingTasks: []))
    #expect(!CopyWorker.shouldPostFinished(afterDelayRemainingTasks: [task]))
}

@Test func copyWorkerSkipsTasksDeletedBeforeTheyStart() {
    #expect(CopyWorker.shouldStartTask(isTaskStillQueued: true))
    #expect(!CopyWorker.shouldStartTask(isTaskStillQueued: false))
}

@Test func copyWorkerDiscardsCompletedCopyWhenTaskWasDeleted() {
    #expect(CopyWorker.shouldKeepCompletedCopy(isTaskStillQueued: true))
    #expect(!CopyWorker.shouldKeepCompletedCopy(isTaskStillQueued: false))
}

@Test func copyDBSeesTasksDeletedFromSeparateContext() async throws {
    let schema = Schema([CopyTask.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = CopyDB(container, reason: "CopyDBTests", verbose: false)
    let bookmark = Data([42])

    await db.newCopyTask(
        bookmark: bookmark,
        destination: URL(fileURLWithPath: "/tmp/cisum-audio-copy-tests", isDirectory: true),
        originalFilename: "track.mp3"
    )

    #expect(await db.hasCopyTask(bookmark: bookmark))

    let tasks = CopyDB.getAllTasks(from: container)
    try CopyDB.deleteTasks(tasks, from: container)

    #expect(await !db.hasCopyTask(bookmark: bookmark))
}

private final class TestNotificationValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Value

    init(_ value: Value) {
        self.storedValue = value
    }

    var value: Value {
        lock.withLock { storedValue }
    }

    func set(_ value: Value) {
        lock.withLock {
            storedValue = value
        }
    }
}
#endif

// MARK: - CopyDB 行为

@Test func copyDBNewTaskDeduplicatesByBookmark() async throws {
    let schema = Schema([CopyTask.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = CopyDB(container, reason: "CopyDBDedupe", verbose: false)
    let bookmark = Data([7, 8])

    await db.newCopyTask(bookmark: bookmark, destination: URL(fileURLWithPath: "/tmp/copy-db", isDirectory: true), originalFilename: "a.mp3")
    await db.newCopyTask(bookmark: bookmark, destination: URL(fileURLWithPath: "/tmp/copy-db", isDirectory: true), originalFilename: "b.mp3")

    let tasks = await db.allCopyTaskDTOs()
    #expect(tasks.count == 1)
    #expect(tasks.first?.originalFilename == "a.mp3")
}

@Test func copyDBFindAndHasTaskMatchByBookmark() async throws {
    let schema = Schema([CopyTask.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = CopyDB(container, reason: "CopyDBFind", verbose: false)
    let bookmark = Data([1, 2, 3])

    #expect(await !db.hasCopyTask(bookmark: bookmark))

    await db.newCopyTask(bookmark: bookmark, destination: URL(fileURLWithPath: "/tmp/copy-db", isDirectory: true), originalFilename: "song.mp3")

    #expect(await db.hasCopyTask(bookmark: bookmark))
    #expect((await db.allCopyTaskDTOs()).first?.originalFilename == "song.mp3")
}

@Test func copyDBSetRunningAndErrorStatesPersist() async throws {
    let schema = Schema([CopyTask.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = CopyDB(container, reason: "CopyDBStates", verbose: false)
    let bookmark = Data([9])
    let destination = URL(fileURLWithPath: "/tmp/copy-db", isDirectory: true)

    await db.newCopyTask(bookmark: bookmark, destination: destination, originalFilename: "clip.m4a")
    try await db.setTasksRunning(bookmarks: [bookmark])

    #expect(await db.hasCopyTask(bookmark: bookmark))

    await db.setTaskError(bookmark: bookmark, error: "disk full")
    let stored = await db.allCopyTaskDTOs()
    #expect(stored.first?.error == "disk full")

    await db.setTaskError(bookmark: bookmark, error: "missing source")
    #expect((await db.allCopyTaskDTOs()).first?.error == "missing source")
}

@Test func copyDBDeleteByBookmarksAndById() async throws {
    let schema = Schema([CopyTask.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = CopyDB(container, reason: "CopyDBDelete", verbose: false)
    let keepBookmark = Data([11])
    let dropBookmark = Data([12])
    let destination = URL(fileURLWithPath: "/tmp/copy-db", isDirectory: true)

    await db.newCopyTask(bookmark: keepBookmark, destination: destination, originalFilename: "keep.mp3")
    await db.newCopyTask(bookmark: dropBookmark, destination: destination, originalFilename: "drop.mp3")

    try await db.deleteCopyTasks(bookmarks: [dropBookmark])
    #expect(await db.hasCopyTask(bookmark: keepBookmark))
    #expect(await !db.hasCopyTask(bookmark: dropBookmark))

    let toDelete = CopyDB.getAllTasks(from: container).first { $0.bookmark == keepBookmark }!
    await db.deleteCopyTask(toDelete.id)
    #expect(await !db.hasCopyTask(bookmark: keepBookmark))
}

@Test func copyDBDTOsExposePersistedState() async throws {
    let schema = Schema([CopyTask.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = CopyDB(container, reason: "CopyDBDTO", verbose: false)
    let bookmark = Data([21])

    await db.newCopyTask(bookmark: bookmark, destination: URL(fileURLWithPath: "/tmp/copy-db", isDirectory: true), originalFilename: "podcast.m4a")
    await db.setTaskError(bookmark: bookmark, error: "failed")

    let dtos = await db.allCopyTaskDTOs()
    #expect(dtos.count == 1)
    #expect(dtos.first?.originalFilename == "podcast.m4a")
    #expect(dtos.first?.error == "failed")
    #expect(dtos.first?.destination == URL(fileURLWithPath: "/tmp/copy-db", isDirectory: true))
}

// MARK: - CopyWorker 静态分支

@Test func copyWorkerSourceAccessHonorsScopeAndReadability() throws {
    #expect(CopyWorker.hasCopySourceAccess(URL(fileURLWithPath: "/missing"), securityScopeGranted: true))
    #expect(CopyWorker.hasCopySourceAccess(URL(fileURLWithPath: "/missing"), securityScopeGranted: false) == (FileManager.default.isReadableFile(atPath: "/missing") && FileManager.default.fileExists(atPath: "/missing")))
}

@Test func copyWorkerReservesUniqueNamesAcrossSameFolderTasks() {
    let folder = URL(fileURLWithPath: "/tmp/copy-unique", isDirectory: true)
    let tasks = [
        CopyTaskDTO(bookmark: Data([1]), destination: folder, originalFilename: "track.mp3"),
        CopyTaskDTO(bookmark: Data([2]), destination: folder, originalFilename: "track.mp3"),
        CopyTaskDTO(bookmark: Data([3]), destination: folder, originalFilename: "track.mp3")
    ]

    let urls = CopyWorker.makeUniqueDestinationURLs(for: tasks, fileExists: { _ in false })
    #expect(urls[0].lastPathComponent == "track.mp3")
    #expect(urls[1].lastPathComponent == "track 2.mp3")
    #expect(urls[2].lastPathComponent == "track 3.mp3")
}
