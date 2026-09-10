import Testing
import Foundation
import SwiftData
@testable import PluginAudioDBData
import ProviderAudioLibrary

@Test func audioPluginInfoExportsMetadata() {
    #expect(AudioPluginInfo.titleKey == "Music")
    #expect(AudioPluginInfo.maxAudioCount == 100)
    #expect(AudioPluginInfo.supportedExtensions.contains("mp3"))
}

@Test func audioPluginSupportsPlayerRecognizedAudioExtensions() {
    let playerAudioExtensions = ["mp3", "m4a", "aac", "wav", "aiff", "ogg", "opus", "flac", "alac"]

    for extensionName in playerAudioExtensions {
        #expect(AudioPluginInfo.supportedExtensions.contains(extensionName))
    }
}

@MainActor
@Test func audioDiskCreationReplacesDanglingSymlink() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let audioDisk = root.appendingPathComponent(AudioPluginInfo.effectiveDBDirName, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
        at: audioDisk,
        withDestinationURL: root.appendingPathComponent("missing-audio", isDirectory: true)
    )

    let preparedDisk = try audioDisk.ensureDirectory()
    var isDirectory: ObjCBool = false

    #expect(preparedDisk == audioDisk)
    #expect(FileManager.default.fileExists(atPath: audioDisk.path, isDirectory: &isDirectory))
    #expect(isDirectory.boolValue)
    #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: audioDisk.path)) == nil)
}

@MainActor
@Test func audioDBUpdatedNotificationPostsSynchronouslyOnMainThread() {
    let receivedCount = TestNotificationCounter()
    let token = NotificationCenter.default.addObserver(
        forName: .dbUpdated,
        object: nil,
        queue: nil
    ) { _ in
        receivedCount.increment()
    }
    defer { NotificationCenter.default.removeObserver(token) }

    NotificationCenter.postDBUpdated()

    #expect(receivedCount.value == 1)
}

@Test func audioDBUniqueSupportedFilesDeduplicatesByResolvedIdentity() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realRoot = root.appendingPathComponent("real-audio", isDirectory: true)
    let linkedRoot = root.appendingPathComponent("audio-link", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realRoot, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: realRoot)

    let linkedAudio = linkedRoot.appendingPathComponent("track.mp3")
    let realAudio = realRoot.appendingPathComponent("track.mp3")
    let otherAudio = realRoot.appendingPathComponent("other.mp3")
    try Data("audio".utf8).write(to: realAudio)
    try Data("audio".utf8).write(to: otherAudio)

    #expect(AudioDB.canonicalAudioIdentity(for: linkedAudio) == AudioDB.canonicalAudioIdentity(for: realAudio))
    #expect(AudioDB.uniqueSupportedAudioFiles([linkedAudio, realAudio, otherAudio]) == [linkedAudio, otherAudio])
}

@Test func audioDBUniqueSupportedFilesKeepsDistinctDanglingSymlinkAudio() throws {
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

    #expect(!AudioDB.representsSameAudioFile(firstLink, secondLink))
    #expect(AudioDB.uniqueSupportedAudioFiles([firstLink, secondLink]) == [firstLink, secondLink])
}

@Test func audioDBNextOfReturnsFollowingOrderedTrack() async throws {
    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = AudioDB(container, reason: "audioDBNextOfReturnsFollowingOrderedTrack")

    let first = URL(fileURLWithPath: "/tmp/cisum-audio-tests/first.mp3")
    let second = URL(fileURLWithPath: "/tmp/cisum-audio-tests/second.mp3")

    await db.insertAudio(url: first, order: 10)
    await db.insertAudio(url: second, order: 20)

    let next = try await db.getNextAudioURLOf(first)
    #expect(next == second)
}

@Test func audioDBNextOfReturnsNilAtLastTrack() async throws {
    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = AudioDB(container, reason: "audioDBNextOfReturnsNilAtLastTrack")

    let first = URL(fileURLWithPath: "/tmp/cisum-audio-tests/first.mp3")
    let second = URL(fileURLWithPath: "/tmp/cisum-audio-tests/second.mp3")

    await db.insertAudio(url: first, order: 10)
    await db.insertAudio(url: second, order: 20)

    let next = try await db.getNextAudioURLOf(second)
    #expect(next == nil)
}

@Test
@MainActor
func audioRepoNavigationWrapsAtAudioDBBoundaries() async throws {
    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let context = ModelContext(container)
    let repo = try AudioRepo(
        container: container,
        disk: URL(fileURLWithPath: "/tmp/cisum-audio-tests"),
        reason: "audioRepoNavigationWrapsAtAudioDBBoundaries"
    )

    let first = URL(fileURLWithPath: "/tmp/cisum-audio-tests/first.mp3")
    let middle = URL(fileURLWithPath: "/tmp/cisum-audio-tests/middle.mp3")
    let last = URL(fileURLWithPath: "/tmp/cisum-audio-tests/last.mp3")
    context.insert(AudioModel(first, order: 10))
    context.insert(AudioModel(middle, order: 20))
    context.insert(AudioModel(last, order: 30))
    try context.save()

    #expect(try await repo.getNextOf(last) == first)
    #expect(try await repo.getPrevOf(first) == last)
}

@Test func audioDBNextOfSkipsSymlinkedDuplicateTrack() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realRoot = root.appendingPathComponent("real-audio", isDirectory: true)
    let linkedRoot = root.appendingPathComponent("audio-link", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realRoot, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: realRoot)

    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = AudioDB(container, reason: "audioDBNextOfSkipsSymlinkedDuplicateTrack")

    let realAudio = realRoot.appendingPathComponent("track.mp3")
    let linkedAudio = linkedRoot.appendingPathComponent("track.mp3")
    let nextAudio = realRoot.appendingPathComponent("next.mp3")
    for file in [realAudio, nextAudio] {
        try Data("audio".utf8).write(to: file)
    }

    await db.insertAudio(url: realAudio, order: 10)
    await db.insertAudio(url: linkedAudio, order: 20, force: true)
    await db.insertAudio(url: nextAudio, order: 30)

    let next = try await db.getNextAudioURLOf(realAudio)
    #expect(next == nextAudio)
}

@Test func audioDBPrevOfSkipsSymlinkedDuplicateTrack() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realRoot = root.appendingPathComponent("real-audio", isDirectory: true)
    let linkedRoot = root.appendingPathComponent("audio-link", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realRoot, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: realRoot)

    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = AudioDB(container, reason: "audioDBPrevOfSkipsSymlinkedDuplicateTrack")

    let previousAudio = realRoot.appendingPathComponent("previous.mp3")
    let realAudio = realRoot.appendingPathComponent("track.mp3")
    let linkedAudio = linkedRoot.appendingPathComponent("track.mp3")
    for file in [previousAudio, realAudio] {
        try Data("audio".utf8).write(to: file)
    }

    await db.insertAudio(url: previousAudio, order: 10)
    await db.insertAudio(url: linkedAudio, order: 20, force: true)
    await db.insertAudio(url: realAudio, order: 30)

    let previous = try await db.getPrevAudioURLOf(realAudio)
    #expect(previous == previousAudio)
}

@Test func audioDBDeleteReturnsFollowingTrackAfterSymlinkedDuplicate() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realRoot = root.appendingPathComponent("real-audio", isDirectory: true)
    let linkedRoot = root.appendingPathComponent("audio-link", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realRoot, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: realRoot)

    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = AudioDB(container, reason: "audioDBDeleteReturnsFollowingTrackAfterSymlinkedDuplicate")

    let realAudio = realRoot.appendingPathComponent("track.mp3")
    let linkedAudio = linkedRoot.appendingPathComponent("track.mp3")
    let nextAudio = realRoot.appendingPathComponent("next.mp3")
    for file in [realAudio, nextAudio] {
        try Data("audio".utf8).write(to: file)
    }

    let next = try await db.deleteNextURLAfterSymlinkedDuplicate(
        realAudio: realAudio,
        linkedAudio: linkedAudio,
        nextAudio: nextAudio
    )
    #expect(next == nextAudio)
}

@Test func audioDBBatchDeleteSkipsTracksDeletedLaterInSameBatch() async throws {
    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = AudioDB(container, reason: "audioDBBatchDeleteSkipsTracksDeletedLaterInSameBatch")

    let root = URL(fileURLWithPath: "/tmp/cisum-audio-batch-delete", isDirectory: true)
    let first = root.appendingPathComponent("first.mp3")
    let second = root.appendingPathComponent("second.mp3")
    let third = root.appendingPathComponent("third.mp3")
    let fourth = root.appendingPathComponent("fourth.mp3")

    let next = try await db.deleteNextURLAfterBatchDeleting(
        first: first,
        second: second,
        third: third,
        fourth: fourth
    )

    #expect(next == fourth)
}

@Test func audioDBLastAudioReturnsHighestOrderedTrack() async throws {
    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = AudioDB(container, reason: "audioDBLastAudioReturnsHighestOrderedTrack")

    let first = URL(fileURLWithPath: "/tmp/cisum-audio-tests/first.mp3")
    let second = URL(fileURLWithPath: "/tmp/cisum-audio-tests/second.mp3")

    await db.insertAudio(url: first, order: 10)
    await db.insertAudio(url: second, order: 20)

    let last = try await db.lastAudioURL()
    #expect(last == second)
}

@Test func audioDBDeleteAudiosByURLRemovesFilesAndModels() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = AudioDB(container, reason: "audioDBDeleteAudiosByURLRemovesFilesAndModels")

    let file = root.appendingPathComponent("track.mp3")
    try Data("audio".utf8).write(to: file)
    await db.insertAudio(url: file, order: 10)

    try await db.deleteAudiosByURL(disk: root, urls: [file])

    #expect(FileManager.default.fileExists(atPath: file.path) == false)
    #expect(await db.getTotalOfAudio() == 0)
}

@Test func audioDBContainsHandlesRootAndSiblingPrefixPaths() {
    let root = URL(fileURLWithPath: "/", isDirectory: true)
    let rootChild = URL(fileURLWithPath: "/tmp/cisum-audio-tests/track.mp3")
    let disk = URL(fileURLWithPath: "/tmp/cisum-audio-tests/audio", isDirectory: true)
    let sibling = URL(fileURLWithPath: "/tmp/cisum-audio-tests/audio-backup/track.mp3")

    #expect(AudioDB.contains(root, audioURL: rootChild))
    #expect(!AudioDB.contains(root, audioURL: root))
    #expect(!AudioDB.contains(disk, audioURL: disk))
    #expect(!AudioDB.contains(disk, audioURL: sibling))
}

@Test func audioDBContainsResolvesSymlinkedLibraryRoots() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realDisk = root.appendingPathComponent("real-audio", isDirectory: true)
    let linkedDisk = root.appendingPathComponent("audio-link", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realDisk, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedDisk, withDestinationURL: realDisk)
    let audio = realDisk.appendingPathComponent("track.mp3")
    try Data("audio".utf8).write(to: audio)

    #expect(AudioDB.contains(linkedDisk, audioURL: audio))
}

@Test func audioDBContainsAllowsDanglingSymlinkEntriesInsideLibrary() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let disk = root.appendingPathComponent("audio", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: disk, withIntermediateDirectories: true)
    let linkedAudio = disk.appendingPathComponent("broken.mp3")
    try FileManager.default.createSymbolicLink(
        at: linkedAudio,
        withDestinationURL: root.appendingPathComponent("missing-target.mp3")
    )

    #expect(AudioDB.contains(disk, audioURL: linkedAudio))
}

@Test func audioDBDeleteAudiosByURLRemovesDanglingSymlinkEntries() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let disk = root.appendingPathComponent("audio", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: disk, withIntermediateDirectories: true)

    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = AudioDB(container, reason: "audioDBDeleteAudiosByURLRemovesDanglingSymlinkEntries")

    let linkedAudio = disk.appendingPathComponent("broken.mp3")
    try FileManager.default.createSymbolicLink(
        at: linkedAudio,
        withDestinationURL: root.appendingPathComponent("missing-target.mp3")
    )
    await db.insertAudio(url: linkedAudio, order: 10)

    try await db.deleteAudiosByURL(disk: disk, urls: [linkedAudio])

    #expect(!FileManager.default.fileExists(atPath: linkedAudio.path))
    #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: linkedAudio.path)) == nil)
    #expect(await db.getTotalOfAudio() == 0)
}

@Test func audioDBDeleteAudiosByURLRejectsFilesOutsideLibrary() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let disk = root.appendingPathComponent("audio", isDirectory: true)
    let outside = root.appendingPathComponent("outside", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: disk, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)

    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = AudioDB(container, reason: "audioDBDeleteAudiosByURLRejectsFilesOutsideLibrary")

    let file = outside.appendingPathComponent("track.mp3")
    try Data("audio".utf8).write(to: file)
    await db.insertAudio(url: file, order: 10)

    do {
        try await db.deleteAudiosByURL(disk: disk, urls: [file])
        Issue.record("Deleting a file outside the audio library should fail")
    } catch {
        #expect(error.localizedDescription.contains("outside the current library"))
    }
    #expect(FileManager.default.fileExists(atPath: file.path))
    #expect(await db.getTotalOfAudio() == 1)
}

@Test
@MainActor
func audioRepoSingleDeleteRejectsFilesOutsideLibrary() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let disk = root.appendingPathComponent("audio", isDirectory: true)
    let outside = root.appendingPathComponent("outside", isDirectory: true)
    let databaseURL = root.appendingPathComponent("audio.store")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: disk, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    let file = outside.appendingPathComponent("track.mp3")
    try Data("audio".utf8).write(to: file)

    let repo = try AudioRepo(disk: disk, databaseURL: databaseURL, reason: "audioRepoSingleDeleteRejectsFilesOutsideLibrary")
    await repo.sync([file], isFirst: true)

    do {
        try await repo.delete(AudioModel(file), verbose: false)
        Issue.record("Single-item delete should use the same library containment guard as batch delete")
    } catch {
        #expect(error.localizedDescription.contains("outside the current library"))
    }

    #expect(FileManager.default.fileExists(atPath: file.path))
    #expect(await repo.getTotalCount() == 1)
}

@Test func audioDBDeleteAudiosByURLRejectsLibraryRoot() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = AudioDB(container, reason: "audioDBDeleteAudiosByURLRejectsLibraryRoot")

    await db.insertAudio(url: root, order: 10)

    do {
        try await db.deleteAudiosByURL(disk: root, urls: [root])
        Issue.record("Deleting the audio library root should fail")
    } catch {
        #expect(error.localizedDescription.contains("outside the current library"))
    }
    #expect(FileManager.default.fileExists(atPath: root.path))
    #expect(await db.getTotalOfAudio() == 1)
}

@Test func audioDBDeleteAudiosByURLRejectsMixedBatchBeforeDeleting() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let disk = root.appendingPathComponent("audio", isDirectory: true)
    let outside = root.appendingPathComponent("outside", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: disk, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)

    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = AudioDB(container, reason: "audioDBDeleteAudiosByURLRejectsMixedBatchBeforeDeleting")

    let insideFile = disk.appendingPathComponent("inside.mp3")
    let outsideFile = outside.appendingPathComponent("outside.mp3")
    try Data("audio".utf8).write(to: insideFile)
    try Data("audio".utf8).write(to: outsideFile)
    await db.insertAudio(url: insideFile, order: 10)
    await db.insertAudio(url: outsideFile, order: 20)

    do {
        try await db.deleteAudiosByURL(disk: disk, urls: [insideFile, outsideFile])
        Issue.record("Deleting a mixed batch with a file outside the audio library should fail")
    } catch {
        #expect(error.localizedDescription.contains("outside the current library"))
    }
    #expect(FileManager.default.fileExists(atPath: insideFile.path))
    #expect(FileManager.default.fileExists(atPath: outsideFile.path))
    #expect(await db.getTotalOfAudio() == 2)
}

@Test func audioDBSyncAppendsNewFilesInStablePathOrder() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = AudioDB(container, reason: "audioDBSyncAppendsNewFilesInStablePathOrder")

    let existing = root.appendingPathComponent("00-existing.mp3")
    let second = root.appendingPathComponent("02-second.mp3")
    let first = root.appendingPathComponent("01-first.mp3")
    for file in [existing, second, first] {
        try Data("audio".utf8).write(to: file)
    }

    await db.insertAudio(url: existing, order: 10)
    await db.syncWithUpdatedItems([second, first])

    #expect(await db.allAudioURLs(reason: "test") == [existing, first, second])
}

@Test func audioDBSyncMatchesExistingTrackThroughSymlink() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realRoot = root.appendingPathComponent("real-audio", isDirectory: true)
    let linkedRoot = root.appendingPathComponent("audio-link", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realRoot, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: realRoot)

    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = AudioDB(container, reason: "audioDBSyncMatchesExistingTrackThroughSymlink")

    let realAudio = realRoot.appendingPathComponent("track.mp3")
    let linkedAudio = linkedRoot.appendingPathComponent("track.mp3")
    try Data("audio".utf8).write(to: realAudio)

    await db.insertAudio(url: realAudio, order: 10)
    await db.syncWithUpdatedItems([linkedAudio])

    #expect(await db.allAudioURLs(reason: "test") == [realAudio])
}

@Test func audioDBSyncRemovesDistinctDanglingSymlinkAudioEntries() async throws {
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

    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = AudioDB(container, reason: "audioDBSyncRemovesDistinctDanglingSymlinkAudioEntries")

    await db.insertAudio(url: firstLink, order: 10)
    await db.insertAudio(url: secondLink, order: 20)
    await db.syncWithUpdatedItems([firstLink, secondLink])

    #expect(await db.getTotalOfAudio() == 0)
}

@Test func audioDBFullSyncKeepsSymlinkedExistingTrack() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realRoot = root.appendingPathComponent("real-audio", isDirectory: true)
    let linkedRoot = root.appendingPathComponent("audio-link", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realRoot, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: realRoot)

    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = AudioDB(container, reason: "audioDBFullSyncKeepsSymlinkedExistingTrack")

    let realAudio = realRoot.appendingPathComponent("track.mp3")
    let linkedAudio = linkedRoot.appendingPathComponent("track.mp3")
    try Data("audio".utf8).write(to: realAudio)

    await db.insertAudio(url: realAudio, order: 10)
    await db.initItems([linkedAudio])

    #expect(await db.allAudioURLs(reason: "test") == [realAudio])
}

@Test func audioDBFullSyncDeduplicatesSymlinkedScanItems() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realRoot = root.appendingPathComponent("real-audio", isDirectory: true)
    let linkedRoot = root.appendingPathComponent("audio-link", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realRoot, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: realRoot)

    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = AudioDB(container, reason: "audioDBFullSyncDeduplicatesSymlinkedScanItems")

    let realAudio = realRoot.appendingPathComponent("track.mp3")
    let linkedAudio = linkedRoot.appendingPathComponent("track.mp3")
    try Data("audio".utf8).write(to: realAudio)

    await db.initItems([linkedAudio, realAudio])

    #expect(await db.allAudioURLs(reason: "test") == [linkedAudio])
}

@Test func audioDBDeleteByURLMatchesSymlinkedStoredTrack() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realRoot = root.appendingPathComponent("real-audio", isDirectory: true)
    let linkedRoot = root.appendingPathComponent("audio-link", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realRoot, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: realRoot)

    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = AudioDB(container, reason: "audioDBDeleteByURLMatchesSymlinkedStoredTrack")

    let realAudio = realRoot.appendingPathComponent("track.mp3")
    let linkedAudio = linkedRoot.appendingPathComponent("track.mp3")
    try Data("audio".utf8).write(to: realAudio)

    await db.insertAudio(url: realAudio, order: 10)
    try await db.deleteAudiosByURL(disk: linkedRoot, urls: [linkedAudio])

    #expect(FileManager.default.fileExists(atPath: realAudio.path) == false)
    #expect(await db.getTotalOfAudio() == 0)
}

@Test func audioDBSyncIgnoresFoldersAndUnsupportedFiles() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = AudioDB(container, reason: "audioDBSyncIgnoresFoldersAndUnsupportedFiles")

    let folder = root.appendingPathComponent("folder", isDirectory: true)
    let notes = root.appendingPathComponent("notes.txt")
    let audio = root.appendingPathComponent("track.mp3")

    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try Data("notes".utf8).write(to: notes)
    try Data("audio".utf8).write(to: audio)

    await db.syncWithUpdatedItems([folder, notes, audio])
    #expect(await db.allAudioURLs(reason: "test") == [audio])

    await db.initItems([folder, notes, audio])
    #expect(await db.allAudioURLs(reason: "test") == [audio])
}

@Test func audioDBFullSyncRepairsDuplicateLegacyAudioOrders() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let db = AudioDB(container, reason: "audioDBFullSyncRepairsDuplicateLegacyAudioOrders")

    let second = root.appendingPathComponent("02-second.mp3")
    let first = root.appendingPathComponent("01-first.mp3")
    for file in [second, first] {
        try Data("audio".utf8).write(to: file)
        await db.insertAudio(url: file, order: 0)
    }

    await db.initItems([second, first])

    #expect(await db.allAudioURLs(reason: "test") == [first, second])
}

@Test func audioDBKeepsUniqueExistingAudioOrders() {
    #expect(!AudioDB.needsStableOrderRepair([20, 10, 30]))
    #expect(!AudioDB.needsStableOrderRepair([-1, -1, 10]))
    #expect(AudioDB.needsStableOrderRepair([0, 0]))
}

@Test func audioDBClampsInvalidPaginationBounds() {
    let negativeBounds = AudioDB.normalizedPagination(offset: -10, limit: -5)
    #expect(negativeBounds.offset == 0)
    #expect(negativeBounds.limit == 0)

    let validBounds = AudioDB.normalizedPagination(offset: 20, limit: 50)
    #expect(validBounds.offset == 20)
    #expect(validBounds.limit == 50)
}

@Test func audioDBClampsInvalidRandomAudioCount() {
    #expect(AudioDB.normalizedRandomAudioCount(-1) == 0)
    #expect(AudioDB.normalizedRandomAudioCount(0) == 0)
    #expect(AudioDB.normalizedRandomAudioCount(100) == 100)
}

@Test func audioDBNextBatchDownloadPlanStopsAtEndOfQueue() {
    let nextByTrack = [
        "first": "second",
        "second": "third",
    ]

    #expect(AudioDB.nextBatchDownloadPlan(start: "first", count: 6) { nextByTrack[$0] } == [
        "first",
        "second",
        "third",
    ])
    #expect(AudioDB.nextBatchDownloadPlan(start: "first", count: 2) { nextByTrack[$0] } == [
        "first",
        "second",
    ])
    #expect(AudioDB.nextBatchDownloadPlan(start: "first", count: 0) { nextByTrack[$0] }.isEmpty)
}

@Test func audioModelUsesProvidedTitleWhenAvailable() {
    let url = URL(fileURLWithPath: "/tmp/audio-file-name.mp3")

    #expect(AudioModel(url, title: "  Metadata Title  ").title == "Metadata Title")
    #expect(AudioModel(url, title: "").title == "audio-file-name")
    #expect(AudioModel(url, title: " \n\t ").title == "audio-file-name")
    #expect(AudioModel(url).title == "audio-file-name")
}

extension AudioDB {
    func deleteNextURLAfterSymlinkedDuplicate(realAudio: URL, linkedAudio: URL, nextAudio: URL) throws -> URL? {
        let audio = AudioModel(realAudio)
        audio.order = 10
        insertAudio(audio, force: true)
        insertAudio(url: linkedAudio, order: 20, force: true)
        insertAudio(url: nextAudio, order: 30, force: true)

        return try deleteAudios(ids: [audio.id], verbose: false)?.url
    }

    func deleteNextURLAfterBatchDeleting(
        first: URL,
        second: URL,
        third: URL,
        fourth: URL
    ) throws -> URL? {
        insertAudio(url: first, order: 10, force: true)
        let secondAudio = AudioModel(second, order: 20)
        let thirdAudio = AudioModel(third, order: 30)
        insertAudio(secondAudio, force: true)
        insertAudio(thirdAudio, force: true)
        insertAudio(url: fourth, order: 40, force: true)

        return try deleteAudios(ids: [thirdAudio.id, secondAudio.id], verbose: false)?.url
    }
}

private final class TestNotificationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() {
        lock.withLock {
            count += 1
        }
    }
}
