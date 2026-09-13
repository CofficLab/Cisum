import Foundation
import MagicPlayMan
import Testing
@testable import PluginAudioProgress

@Test func audioProgressInfoExportsMetadata() {
    #expect(AudioProgressPluginInfo.titleKey == "Audio Progress")
}

@Test func leavingAudioScenePersistsProgress() {
    #expect(AudioProgressPersistencePolicy.shouldPersistWhenSceneChanges(
        from: "audio",
        to: "book",
        audioSceneName: "audio"
    ))
}

@Test func enteringAudioSceneDoesNotPersistStaleProgress() {
    #expect(!AudioProgressPersistencePolicy.shouldPersistWhenSceneChanges(
        from: "book",
        to: "audio",
        audioSceneName: "audio"
    ))
}

@Test func stayingInAudioSceneDoesNotDuplicateProgressSave() {
    #expect(!AudioProgressPersistencePolicy.shouldPersistWhenSceneChanges(
        from: "audio",
        to: "audio",
        audioSceneName: "audio"
    ))
}

@Test func clearingCurrentAudioURLPersistsNilCurrentAudio() {
    let stored = URL(fileURLWithPath: "/tmp/audio/track.mp3")

    #expect(AudioProgressPersistencePolicy.currentURLToStore(
        nil,
        storedURL: stored,
        supportedExtensions: ["mp3"]
    ) == nil)
}

@Test func supportedCurrentAudioURLPersistsCurrentAudio() {
    let stored = URL(fileURLWithPath: "/tmp/audio/track-01.mp3")
    let current = URL(fileURLWithPath: "/tmp/audio/track-02.FLAC")

    #expect(AudioProgressPersistencePolicy.currentURLToStore(
        current,
        storedURL: stored,
        supportedExtensions: ["mp3", "flac"]
    ) == current)
}

@Test func unsupportedCurrentURLKeepsPreviousAudio() {
    let stored = URL(fileURLWithPath: "/tmp/audio/track.mp3")
    let video = URL(fileURLWithPath: "/tmp/video/movie.mp4")

    #expect(AudioProgressPersistencePolicy.currentURLToStore(
        video,
        storedURL: stored,
        supportedExtensions: ["mp3"]
    ) == stored)
}

@Test func emptyCloudAudioURLIsIgnored() {
    #expect(AudioStateRepo.storedURL(from: "") == nil)
    #expect(AudioStateRepo.storedURL(from: nil) == nil)
    #expect(AudioStateRepo.storedURL(from: "file:///tmp/audio/track.mp3") == URL(fileURLWithPath: "/tmp/audio/track.mp3"))
    #expect(AudioStateRepo.storedURL(from: "  file:///tmp/audio/spaced.mp3\n") == URL(fileURLWithPath: "/tmp/audio/spaced.mp3"))
    #expect(AudioStateRepo.storedURL(from: "/tmp/audio/legacy-track.mp3") == URL(fileURLWithPath: "/tmp/audio/legacy-track.mp3"))
    #expect(AudioStateRepo.storedURL(from: "\t/tmp/audio/legacy-spaced.mp3 ") == URL(fileURLWithPath: "/tmp/audio/legacy-spaced.mp3"))
    #expect(AudioStateRepo.storedURL(from: "not a url") == nil)
}

@Test func localZeroAudioTimeOverridesStaleCloudTime() {
    #expect(AudioStateRepo.storedTime(
        localObject: 0.0,
        localDouble: 0,
        cloudString: "42"
    ) == 0)
    #expect(AudioStateRepo.storedTime(
        localObject: nil,
        localDouble: 0,
        cloudString: "42"
    ) == 42)
    #expect(AudioStateRepo.storedTime(
        localObject: nil,
        localDouble: 0,
        cloudString: "not a time"
    ) == nil)
}

@Test func invalidLocalAudioTimesFallBackToCloud() {
    #expect(AudioStateRepo.storedTime(
        localObject: Double.nan,
        localDouble: .nan,
        cloudString: "42"
    ) == 42)
    #expect(AudioStateRepo.storedTime(
        localObject: Double.infinity,
        localDouble: .infinity,
        cloudString: "42"
    ) == 42)
    #expect(AudioStateRepo.storedTime(
        localObject: -1.0,
        localDouble: -1,
        cloudString: "42"
    ) == 42)
    #expect(AudioStateRepo.storedTime(
        localObject: nil,
        localDouble: 0,
        cloudString: "inf"
    ) == nil)
    #expect(AudioStateRepo.storedTime(
        localObject: nil,
        localDouble: 0,
        cloudString: "-1"
    ) == nil)
}

@Test func audioTimesAreNormalizedBeforeStorage() {
    #expect(AudioStateRepo.normalizedTimeForStorage(.nan) == 0)
    #expect(AudioStateRepo.normalizedTimeForStorage(.infinity) == 0)
    #expect(AudioStateRepo.normalizedTimeForStorage(-1) == 0)
    #expect(AudioStateRepo.normalizedTimeForStorage(0) == 0)
    #expect(AudioStateRepo.normalizedTimeForStorage(42) == 42)
}

@Test func invalidLocalAudioPlayModeFallsBackToCloudMode() {
    #expect(AudioStateRepo.resolvedPlayMode(
        localRawValue: MagicPlayMode.loop.rawValue,
        cloudRawValue: MagicPlayMode.shuffle.rawValue
    ) == .loop)
    #expect(AudioStateRepo.resolvedPlayMode(
        localRawValue: "legacy-corrupt-mode",
        cloudRawValue: MagicPlayMode.shuffle.rawValue
    ) == .shuffle)
    #expect(AudioStateRepo.resolvedPlayMode(
        localRawValue: "legacy-corrupt-mode",
        cloudRawValue: "also-corrupt"
    ) == nil)
}

@Test func differentCurrentAudioURLResetsGlobalRestoreTime() {
    let oldURL = URL(fileURLWithPath: "/tmp/audio/track-01.mp3")
    let newURL = URL(fileURLWithPath: "/tmp/audio/track-02.mp3")

    #expect(AudioProgressPersistencePolicy.shouldResetGlobalTimeWhenCurrentURLChanges(from: oldURL, to: newURL))
    #expect(AudioProgressPersistencePolicy.shouldResetGlobalTimeWhenCurrentURLChanges(from: oldURL, to: nil))
    #expect(!AudioProgressPersistencePolicy.shouldResetGlobalTimeWhenCurrentURLChanges(from: oldURL, to: oldURL))
}

@Test func symlinkedCurrentAudioURLDoesNotResetGlobalRestoreTime() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realFolder = root.appendingPathComponent("real-audio", isDirectory: true)
    let linkedFolder = root.appendingPathComponent("linked-audio", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realFolder, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedFolder, withDestinationURL: realFolder)
    let realTrack = realFolder.appendingPathComponent("track-01.mp3")
    let linkedTrack = linkedFolder.appendingPathComponent("track-01.mp3")
    try Data("audio".utf8).write(to: realTrack)

    #expect(!AudioProgressPersistencePolicy.shouldResetGlobalTimeWhenCurrentURLChanges(
        from: linkedTrack,
        to: realTrack
    ))
}

@Test func distinctDanglingSymlinkCurrentAudioURLResetsGlobalRestoreTime() throws {
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

    #expect(AudioProgressPersistencePolicy.shouldResetGlobalTimeWhenCurrentURLChanges(
        from: firstLink,
        to: secondLink
    ))
}

@Test func invalidRestoredAudioURLShouldClearCurrentAudio() {
    let url = URL(fileURLWithPath: "/tmp/audio/missing.mp3")

    #expect(AudioProgressPersistencePolicy.shouldClearRestoredCurrentURL(storedURL: url, isPlayable: false))
    #expect(!AudioProgressPersistencePolicy.shouldClearRestoredCurrentURL(storedURL: url, isPlayable: true))
    #expect(!AudioProgressPersistencePolicy.shouldClearRestoredCurrentURL(storedURL: nil, isPlayable: false))
    #expect(AudioProgressPersistencePolicy.shouldClearRestoredCurrentTime(storedURL: url, isPlayable: false))
    #expect(!AudioProgressPersistencePolicy.shouldClearRestoredCurrentTime(storedURL: url, isPlayable: true))
    #expect(!AudioProgressPersistencePolicy.shouldClearRestoredCurrentTime(storedURL: nil, isPlayable: false))
}

@Test func deletedStoredCurrentAudioShouldClearRestoreState() {
    let root = URL(fileURLWithPath: "/tmp/audio", isDirectory: true)
    let stored = root.appendingPathComponent("track-01.mp3")
    let deleted = root.appendingPathComponent("track-01.mp3")
    let other = root.appendingPathComponent("track-02.mp3")

    #expect(AudioProgressPersistencePolicy.shouldClearStoredCurrentAfterDelete(
        storedURL: stored,
        deletedURLs: [deleted]
    ))
    #expect(!AudioProgressPersistencePolicy.shouldClearStoredCurrentAfterDelete(
        storedURL: stored,
        deletedURLs: [other]
    ))
    #expect(!AudioProgressPersistencePolicy.shouldClearStoredCurrentAfterDelete(
        storedURL: nil,
        deletedURLs: [deleted]
    ))
}

@Test func symlinkedDeletedStoredCurrentAudioShouldClearRestoreState() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realFolder = root.appendingPathComponent("real-audio", isDirectory: true)
    let linkedFolder = root.appendingPathComponent("linked-audio", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realFolder, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedFolder, withDestinationURL: realFolder)
    let realTrack = realFolder.appendingPathComponent("track-01.mp3")
    let linkedTrack = linkedFolder.appendingPathComponent("track-01.mp3")
    try Data("audio".utf8).write(to: realTrack)

    #expect(AudioProgressPersistencePolicy.shouldClearStoredCurrentAfterDelete(
        storedURL: linkedTrack,
        deletedURLs: [realTrack]
    ))
}

@Test func danglingSymlinkStoredCurrentAudioShouldClearRestoreState() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let missingTrack = root.appendingPathComponent("missing.mp3")
    let linkedTrack = root.appendingPathComponent("linked.mp3")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedTrack, withDestinationURL: missingTrack)

    #expect(AudioProgressPersistencePolicy.shouldClearStoredCurrentAfterDelete(
        storedURL: linkedTrack,
        deletedURLs: [linkedTrack]
    ))
}

@Test func distinctDanglingSymlinkDeletedAudioDoesNotClearRestoreState() throws {
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

    #expect(!AudioProgressPersistencePolicy.shouldClearStoredCurrentAfterDelete(
        storedURL: secondLink,
        deletedURLs: [firstLink]
    ))
}

@Test func restoreResultOnlyAppliesWhenCurrentAudioDidNotChange() {
    let starting = URL(fileURLWithPath: "/tmp/audio/track-01.mp3")
    let switched = URL(fileURLWithPath: "/tmp/audio/track-02.mp3")

    #expect(AudioProgressPersistencePolicy.shouldApplyRestoreResult(
        startingAsset: nil,
        currentAsset: nil
    ))
    #expect(AudioProgressPersistencePolicy.shouldApplyRestoreResult(
        startingAsset: starting,
        currentAsset: starting
    ))
    #expect(!AudioProgressPersistencePolicy.shouldApplyRestoreResult(
        startingAsset: nil,
        currentAsset: switched
    ))
    #expect(!AudioProgressPersistencePolicy.shouldApplyRestoreResult(
        startingAsset: starting,
        currentAsset: switched
    ))
}

@Test func staleAudioRestoreRequestDoesNotApplyAfterSceneChange() {
    #expect(AudioProgressPersistencePolicy.shouldApplyRestoreRequest(
        currentGeneration: 4,
        requestGeneration: 4,
        isSceneActive: true
    ))
    #expect(!AudioProgressPersistencePolicy.shouldApplyRestoreRequest(
        currentGeneration: 5,
        requestGeneration: 4,
        isSceneActive: true
    ))
    #expect(!AudioProgressPersistencePolicy.shouldApplyRestoreRequest(
        currentGeneration: 4,
        requestGeneration: 4,
        isSceneActive: false
    ))
}

@Test func restoreDoesNotReplayAlreadyLoadedAudio() {
    let restored = URL(fileURLWithPath: "/tmp/audio/track-01.mp3")
    let other = URL(fileURLWithPath: "/tmp/audio/track-02.mp3")

    #expect(!AudioProgressPersistencePolicy.shouldPlayRestoredAsset(
        restoredAsset: restored,
        currentAsset: restored
    ))
    #expect(AudioProgressPersistencePolicy.shouldPlayRestoredAsset(
        restoredAsset: restored,
        currentAsset: other
    ))
    #expect(AudioProgressPersistencePolicy.shouldPlayRestoredAsset(
        restoredAsset: restored,
        currentAsset: nil
    ))
}

@Test func restoreTreatsSymlinkedCurrentAudioAsAlreadyLoaded() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realFolder = root.appendingPathComponent("real-audio", isDirectory: true)
    let linkedFolder = root.appendingPathComponent("linked-audio", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: realFolder, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedFolder, withDestinationURL: realFolder)
    let realTrack = realFolder.appendingPathComponent("track-01.mp3")
    let linkedTrack = linkedFolder.appendingPathComponent("track-01.mp3")
    try Data("audio".utf8).write(to: realTrack)

    #expect(AudioProgressPersistencePolicy.shouldApplyRestoreResult(
        startingAsset: linkedTrack,
        currentAsset: realTrack
    ))
    #expect(!AudioProgressPersistencePolicy.shouldPlayRestoredAsset(
        restoredAsset: linkedTrack,
        currentAsset: realTrack
    ))
    #expect(AudioProgressPersistencePolicy.shouldApplyCurrentURLChange(
        requestedURL: linkedTrack,
        currentAsset: realTrack
    ))
    #expect(AudioProgressPersistencePolicy.shouldApplyWidgetMetadataResult(
        requestedAsset: linkedTrack,
        currentAsset: realTrack
    ))
}

@Test func restoreDoesNotTreatDistinctDanglingSymlinksAsCurrentAudio() throws {
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

    #expect(!AudioProgressPersistencePolicy.shouldApplyRestoreResult(
        startingAsset: firstLink,
        currentAsset: secondLink
    ))
    #expect(AudioProgressPersistencePolicy.shouldPlayRestoredAsset(
        restoredAsset: firstLink,
        currentAsset: secondLink
    ))
    #expect(!AudioProgressPersistencePolicy.shouldApplyCurrentURLChange(
        requestedURL: firstLink,
        currentAsset: secondLink
    ))
    #expect(!AudioProgressPersistencePolicy.shouldApplyWidgetMetadataResult(
        requestedAsset: firstLink,
        currentAsset: secondLink
    ))
}

@Test func staleWidgetClearDoesNotOverwriteNewAudio() {
    let current = URL(fileURLWithPath: "/tmp/audio/track-01.mp3")

    #expect(AudioProgressPersistencePolicy.shouldApplyWidgetClearResult(currentAsset: nil))
    #expect(!AudioProgressPersistencePolicy.shouldApplyWidgetClearResult(currentAsset: current))
}

@Test func staleCurrentAudioURLChangeDoesNotOverwriteNewTrack() {
    let requested = URL(fileURLWithPath: "/tmp/audio/track-01.mp3")
    let switched = URL(fileURLWithPath: "/tmp/audio/track-02.mp3")

    #expect(AudioProgressPersistencePolicy.shouldApplyCurrentURLChange(
        requestedURL: requested,
        currentAsset: requested
    ))
    #expect(!AudioProgressPersistencePolicy.shouldApplyCurrentURLChange(
        requestedURL: requested,
        currentAsset: switched
    ))
    #expect(!AudioProgressPersistencePolicy.shouldApplyCurrentURLChange(
        requestedURL: requested,
        currentAsset: nil
    ))
    #expect(AudioProgressPersistencePolicy.shouldApplyCurrentURLChange(
        requestedURL: nil,
        currentAsset: nil
    ))
}

@Test func staleCurrentAudioURLChangeDoesNotApplyAfterSceneInvalidation() {
    let requested = URL(fileURLWithPath: "/tmp/audio/track-01.mp3")

    #expect(AudioProgressPersistencePolicy.shouldApplyCurrentURLChange(
        requestedURL: requested,
        currentAsset: requested,
        currentGeneration: 1,
        requestGeneration: 1,
        isSceneActive: true
    ))
    #expect(!AudioProgressPersistencePolicy.shouldApplyCurrentURLChange(
        requestedURL: requested,
        currentAsset: requested,
        currentGeneration: 2,
        requestGeneration: 1,
        isSceneActive: true
    ))
    #expect(!AudioProgressPersistencePolicy.shouldApplyCurrentURLChange(
        requestedURL: requested,
        currentAsset: requested,
        currentGeneration: 1,
        requestGeneration: 1,
        isSceneActive: false
    ))
}

@Test func widgetMetadataResultOnlyAppliesToStillCurrentAudio() {
    let requested = URL(fileURLWithPath: "/tmp/audio/track-01.mp3")
    let switched = URL(fileURLWithPath: "/tmp/audio/track-02.mp3")

    #expect(AudioProgressPersistencePolicy.shouldApplyWidgetMetadataResult(
        requestedAsset: requested,
        currentAsset: requested
    ))
    #expect(!AudioProgressPersistencePolicy.shouldApplyWidgetMetadataResult(
        requestedAsset: requested,
        currentAsset: switched
    ))
    #expect(!AudioProgressPersistencePolicy.shouldApplyWidgetMetadataResult(
        requestedAsset: requested,
        currentAsset: nil
    ))
}

// MARK: - AudioStateRepo 存取 round-trip

@Suite(.serialized)
struct AudioStateRepoTests {
    @Test
    func playModeRoundTrip() {
        defer { AudioStateRepo.storePlayMode(MagicPlayMode.sequence.rawValue) }

        AudioStateRepo.storePlayMode(MagicPlayMode.shuffle.rawValue)
        #expect(AudioStateRepo.getPlayMode() == .shuffle)
    }

    @Test
    func currentURLRoundTripAndClear() {
        defer { AudioStateRepo.storeCurrent(nil) }

        let url = URL(fileURLWithPath: "/tmp/state-repo.mp3")
        AudioStateRepo.storeCurrent(url)
        #expect(AudioStateRepo.getCurrent() == url)

        AudioStateRepo.storeCurrent(nil)
        #expect(AudioStateRepo.getCurrent() == nil)
    }

    @Test
    func currentTimeRoundTripAndNormalization() {
        defer { AudioStateRepo.storeCurrentTime(0) }

        AudioStateRepo.storeCurrentTime(123.5)
        #expect(AudioStateRepo.getCurrentTime() == 123.5)

        // 非法时间归一化为 0。
        #expect(AudioStateRepo.normalizedTimeForStorage(.nan) == 0)
        #expect(AudioStateRepo.normalizedTimeForStorage(-5) == 0)
        #expect(AudioStateRepo.normalizedTimeForStorage(8) == 8)
    }

    @Test
    func storedURLParsesSchemesAndPaths() {
        #expect(AudioStateRepo.storedURL(from: nil) == nil)
        #expect(AudioStateRepo.storedURL(from: "   ") == nil)
        #expect(AudioStateRepo.storedURL(from: "file:///tmp/a.mp3") == URL(fileURLWithPath: "/tmp/a.mp3"))
        #expect(AudioStateRepo.storedURL(from: "/tmp/b.mp3") == URL(fileURLWithPath: "/tmp/b.mp3"))
        #expect(AudioStateRepo.storedURL(from: "not-a-url") == nil)
    }

    @Test
    func resolvedPlayModePrefersLocalOverCloud() {
        #expect(AudioStateRepo.resolvedPlayMode(localRawValue: "loop", cloudRawValue: nil) == .loop)
        #expect(AudioStateRepo.resolvedPlayMode(localRawValue: nil, cloudRawValue: "shuffle") == .shuffle)
        #expect(AudioStateRepo.resolvedPlayMode(localRawValue: "loop", cloudRawValue: "shuffle") == .loop)
        #expect(AudioStateRepo.resolvedPlayMode(localRawValue: "bogus", cloudRawValue: "bogus2") == nil)
    }
}
