import AVFoundation
import Combine
import ProviderPlayback
@testable import MagicPlayMan
import XCTest

private final class CancellationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        defer { lock.unlock() }
        count += 1
    }
}

// MARK: - MagicPlayMan Async Tests

@MainActor
final class MagicPlayManAsyncTests: XCTestCase {
    // MARK: - Download Observers

    func testReplacingDownloadObserversCancelsPreviousObservers() {
        let man = MagicPlayMan()
        let previousCancellations = CancellationCounter()
        let nextCancellations = CancellationCounter()

        man.setCurrentDownloadObservers((
            asset: URL(fileURLWithPath: "/tmp/previous.mp3"),
            progressObserver: AnyCancellable { previousCancellations.increment() },
            finishObserver: AnyCancellable { previousCancellations.increment() }
        ))

        man.setCurrentDownloadObservers((
            asset: URL(fileURLWithPath: "/tmp/next.mp3"),
            progressObserver: AnyCancellable { nextCancellations.increment() },
            finishObserver: AnyCancellable { nextCancellations.increment() }
        ))

        XCTAssertEqual(previousCancellations.value, 2)
        XCTAssertEqual(nextCancellations.value, 0)
        XCTAssertEqual(man.currentDownloadObservers?.asset, URL(fileURLWithPath: "/tmp/next.mp3"))
    }

    func testResetClearsDownloadObservers() async {
        let man = MagicPlayMan()
        let cancellations = CancellationCounter()

        man.setCurrentDownloadObservers((
            asset: URL(fileURLWithPath: "/tmp/current.mp3"),
            progressObserver: AnyCancellable { cancellations.increment() },
            finishObserver: AnyCancellable { cancellations.increment() }
        ))

        await man.reset(reason: "test")

        XCTAssertNil(man.currentDownloadObservers)
        XCTAssertEqual(cancellations.value, 2)
    }

    // MARK: - Localization

    func testDefaultPlayerHasLocalization() {
        let man = MagicPlayMan(locale: Locale(identifier: "zh_CN"))
        XCTAssertEqual(man.localization.noMediaSelected, "未选择媒体")
    }

    // MARK: - Play Request

    func testNewPlayRequestInvalidatesEarlierRequest() {
        let man = MagicPlayMan()
        let firstRequest = man.beginPlayRequest()
        let secondRequest = man.beginPlayRequest()

        XCTAssertFalse(man.isCurrentPlayRequest(firstRequest))
        XCTAssertTrue(man.isCurrentPlayRequest(secondRequest))
    }

    func testResetInvalidatesPendingPlayRequest() async {
        let man = MagicPlayMan()
        let request = man.beginPlayRequest()
        await man.reset(reason: "test")
        XCTAssertFalse(man.isCurrentPlayRequest(request))
    }

    func testStopInvalidatesPendingPlayRequest() async {
        let man = MagicPlayMan()
        let request = man.beginPlayRequest()
        await man.stop(reason: "test")
        XCTAssertFalse(man.isCurrentPlayRequest(request))
    }

    // MARK: - Notification Normalization

    func testDurationChangedNotificationPayloadIsNormalized() {
        let man = MagicPlayMan()
        var durations: [TimeInterval] = []
        let observer = NotificationCenter.default.addObserver(
            forName: .playManDurationChanged,
            object: man,
            queue: nil
        ) { notification in
            durations.append(notification.userInfo?["duration"] as? TimeInterval ?? -1)
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        man.sendDurationChanged(duration: .nan)
        man.sendDurationChanged(duration: .infinity)
        man.sendDurationChanged(duration: -5)
        man.sendDurationChanged(duration: 42)

        XCTAssertEqual(durations, [0, 0, 0, 42])
    }

    func testTimeUpdateNotificationPayloadIsNormalized() {
        let man = MagicPlayMan()
        var payloads: [(TimeInterval, Double)] = []
        let observer = NotificationCenter.default.addObserver(
            forName: .playManTimeUpdate,
            object: man,
            queue: nil
        ) { notification in
            let currentTime = notification.userInfo?["currentTime"] as? TimeInterval ?? -1
            let progress = notification.userInfo?["progress"] as? Double ?? -1
            payloads.append((currentTime, progress))
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        man.sendTimeUpdate(currentTime: .nan, progress: .infinity)
        man.sendTimeUpdate(currentTime: -4, progress: 1.4)
        man.sendTimeUpdate(currentTime: 12, progress: 0.25)

        XCTAssertEqual(payloads.map(\.0), [0, 0, 12])
        XCTAssertEqual(payloads.map(\.1), [0, 1, 0.25])
    }

    // MARK: - State Management

    func testSetCurrentTimeDoesNotPublishInvalidTimes() {
        let man = MagicPlayMan()
        man.setCurrentTime(.nan, reason: "test")
        XCTAssertEqual(man.currentTime, 0)
        man.setCurrentTime(-5, reason: "test")
        XCTAssertEqual(man.currentTime, 0)
    }

    func testSetCurrentTimeClampsToKnownDuration() {
        let man = MagicPlayMan()
        man.setDuration(100)
        man.setCurrentTime(120, reason: "test")
        XCTAssertEqual(man.currentTime, 100)
    }

    func testSetDurationRejectsInvalidValues() {
        let man = MagicPlayMan()
        man.setDuration(-10)
        XCTAssertEqual(man.duration, 0)
        man.setDuration(.infinity)
        XCTAssertEqual(man.duration, 0)
        man.setDuration(75)
        XCTAssertEqual(man.duration, 75)
    }

    func testSetProgressClampsInvalidValues() {
        let man = MagicPlayMan()
        man.setProgress(1.4)
        XCTAssertEqual(man.progress, 1)
        man.setProgress(-0.2)
        XCTAssertEqual(man.progress, 0)
        man.setProgress(.nan)
        XCTAssertEqual(man.progress, 0)
    }

    // MARK: - Play Mode & Subscribers

    func testRestoringPlayModeDoesNotNotifySubscribers() {
        let man = MagicPlayMan()
        var notifications = 0
        let subscriptionID = man.subscribe(
            name: "MagicPlayManAsyncTests",
            onPlayModeChanged: { _ in
                notifications += 1
            }
        )
        defer {
            man.unsubscribe(subscriptionID)
        }

        man.restorePlayMode(.shuffle)
        XCTAssertEqual(man.playMode, .shuffle)
        XCTAssertEqual(notifications, 0)
    }

    func testUnsubscribeRemovesSubscriberAndCancelsHandlers() {
        let man = MagicPlayMan()
        var notifications = 0
        let subscriptionID = man.subscribe(
            name: "MagicPlayManAsyncTests",
            onPlayModeChanged: { _ in
                notifications += 1
            }
        )

        XCTAssertEqual(man.events.subscribers.count, 1)

        man.unsubscribe(subscriptionID)
        man.setPlayMode(.shuffle)

        XCTAssertEqual(man.events.subscribers.count, 0)
        XCTAssertEqual(notifications, 0)
    }

    // MARK: - Liked Assets

    func testLikedAssetsMatchSymlinkedCurrentAsset() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let realFolder = root.appendingPathComponent("real", isDirectory: true)
        let linkedFolder = root.appendingPathComponent("linked", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: realFolder, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: linkedFolder, withDestinationURL: realFolder)
        let realAsset = realFolder.appendingPathComponent("track.mp3")
        let linkedAsset = linkedFolder.appendingPathComponent("track.mp3")
        try Data("audio".utf8).write(to: realAsset)

        let man = MagicPlayMan()
        man.setLikedAssets([realAsset])
        man.setCurrentURL(linkedAsset)

        XCTAssertTrue(man.isCurrentAssetLiked)
    }

    func testLikedAssetsDoNotMatchDistinctDanglingSymlinkAssets() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let missingAsset = root.appendingPathComponent("missing.mp3")
        let firstLink = root.appendingPathComponent("first.mp3")
        let secondLink = root.appendingPathComponent("second.mp3")
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: firstLink, withDestinationURL: missingAsset)
        try FileManager.default.createSymbolicLink(at: secondLink, withDestinationURL: missingAsset)

        let man = MagicPlayMan()
        man.setLikedAssets([firstLink])
        man.setCurrentURL(secondLink)

        XCTAssertFalse(man.isCurrentAssetLiked)
    }

    func testRemovingLikeClearsSymlinkedStoredAsset() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let realFolder = root.appendingPathComponent("real", isDirectory: true)
        let linkedFolder = root.appendingPathComponent("linked", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: realFolder, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: linkedFolder, withDestinationURL: realFolder)
        let realAsset = realFolder.appendingPathComponent("track.mp3")
        let linkedAsset = linkedFolder.appendingPathComponent("track.mp3")
        try Data("audio".utf8).write(to: realAsset)

        let man = MagicPlayMan()
        man.setLikedAssets([realAsset])
        man.setCurrentURL(linkedAsset)
        man.setLike(false, reason: "test")

        XCTAssertFalse(man.isCurrentAssetLiked)
        XCTAssertTrue(man.likedAssets.isEmpty)
    }

    func testAddingLikeReplacesSymlinkedStoredAsset() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let realFolder = root.appendingPathComponent("real", isDirectory: true)
        let linkedFolder = root.appendingPathComponent("linked", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: realFolder, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: linkedFolder, withDestinationURL: realFolder)
        let realAsset = realFolder.appendingPathComponent("track.mp3")
        let linkedAsset = linkedFolder.appendingPathComponent("track.mp3")
        try Data("audio".utf8).write(to: realAsset)

        let man = MagicPlayMan()
        man.setLikedAssets([realAsset])
        man.setCurrentURL(linkedAsset)
        man.setLike(true, reason: "test")

        XCTAssertEqual(man.likedAssets.count, 1)
        XCTAssertTrue(man.likedAssets.contains(linkedAsset))
    }

    // MARK: - Playback

    func testUnplayableLocalMediaRemainsCurrentSelection() async throws {
        let unplayable = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp3")
        defer {
            try? FileManager.default.removeItem(at: unplayable)
        }

        try Data("not a playable mp3".utf8).write(to: unplayable)

        let man = MagicPlayMan()
        await man.play(unplayable, autoPlay: false, reason: "test")

        XCTAssertEqual(man.currentURL, unplayable)
        XCTAssertEqual(man.currentError, .invalidAsset)
    }

    func testChangingCurrentURLDoesNotSeekLoadedPlayerItem() async throws {
        let audio = try Self.makeSilentWAV()
        defer {
            try? FileManager.default.removeItem(at: audio)
        }

        let man = MagicPlayMan()
        man.player.replaceCurrentItem(with: AVPlayerItem(url: audio))
        try await Self.seek(man.player, to: 0.5)

        man.setCurrentURL(URL(fileURLWithPath: "/tmp/new-track.mp3"))
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertGreaterThan(man.player.currentTime().seconds, 0.3)
    }

    func testFailedPlaybackStateNotifiesFailureSubscribers() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp3")
        let man = MagicPlayMan()
        var receivedError: PlaybackState.PlaybackError?
        let subscriptionID = man.subscribe(
            name: "MagicPlayManAsyncTests",
            onPlaybackFailed: { error in
                receivedError = error
            }
        )
        defer {
            man.unsubscribe(subscriptionID)
        }

        await man.play(missing, autoPlay: false, reason: "test")
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(receivedError, .invalidAsset)
    }

    func testCurrentItemFailureNotificationFailsPlayback() async throws {
        let audio = try Self.makeSilentWAV()
        defer {
            try? FileManager.default.removeItem(at: audio)
        }

        let man = MagicPlayMan()
        let item = AVPlayerItem(url: audio)
        man.player.replaceCurrentItem(with: item)
        man.setCurrentURL(audio)
        man.setDuration(10)
        man.setCurrentTime(5, reason: "test")
        man.setProgress(0.5)
        let error = NSError(domain: "MagicPlayManAsyncTests", code: 99)

        man.handlePlaybackItemFailureNotification(Notification(
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            userInfo: [AVPlayerItemFailedToPlayToEndTimeErrorKey: error]
        ))

        XCTAssertNil(man.player.currentItem)
        XCTAssertEqual(man.currentURL, audio)
        XCTAssertEqual(man.currentTime, 0)
        XCTAssertEqual(man.duration, 0)
        XCTAssertEqual(man.progress, 0)
        XCTAssertEqual(man.currentError, .playbackError(error.localizedDescription))
    }

    func testStaleItemFailureNotificationDoesNotFailCurrentPlayback() async throws {
        let currentAudio = try Self.makeSilentWAV()
        let staleAudio = try Self.makeSilentWAV()
        defer {
            try? FileManager.default.removeItem(at: currentAudio)
            try? FileManager.default.removeItem(at: staleAudio)
        }

        let man = MagicPlayMan()
        let currentItem = AVPlayerItem(url: currentAudio)
        let staleItem = AVPlayerItem(url: staleAudio)
        man.player.replaceCurrentItem(with: currentItem)

        man.handlePlaybackItemFailureNotification(Notification(
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: staleItem,
            userInfo: [AVPlayerItemFailedToPlayToEndTimeErrorKey: NSError(domain: "MagicPlayManAsyncTests", code: 100)]
        ))

        XCTAssertNil(man.currentError)
    }

    func testStopSynchronizesPublishedPlaybackState() async throws {
        let audio = try Self.makeSilentWAV()
        defer {
            try? FileManager.default.removeItem(at: audio)
        }

        let man = MagicPlayMan()
        man.player.replaceCurrentItem(with: AVPlayerItem(url: audio))
        man.setCurrentURL(audio)
        man.setDuration(10)
        man.setCurrentTime(5, reason: "test")
        man.setProgress(0.5)
        man.setState(.playing, reason: "test")

        await man.stop(reason: "test")

        XCTAssertEqual(man.currentURL, audio)
        XCTAssertEqual(man.state, .stopped)
        XCTAssertEqual(man.currentTime, 0)
        XCTAssertEqual(man.progress, 0)
    }

    // MARK: - Get Properties

    func testCurrentErrorReturnsNilWhenNotFailed() {
        let man = MagicPlayMan()
        XCTAssertNil(man.currentError)
    }

    func testCurrentErrorReturnsErrorWhenFailed() {
        let man = MagicPlayMan()
        man.setState(.failed(.noAsset), reason: "test")
        XCTAssertEqual(man.currentError, .noAsset)
    }

    func testHasAssetReturnsFalseWhenNoURL() {
        let man = MagicPlayMan()
        XCTAssertFalse(man.hasAsset)
    }

    func testHasAssetReturnsTrueWhenURLSet() {
        let man = MagicPlayMan()
        man.setCurrentURL(URL(fileURLWithPath: "/tmp/test.mp3"))
        XCTAssertTrue(man.hasAsset)
    }

    func testPlayingPropertyReflectsState() {
        let man = MagicPlayMan()
        XCTAssertFalse(man.playing)
        man.setState(.playing, reason: "test")
        XCTAssertTrue(man.playing)
        man.setState(.paused, reason: "test")
        XCTAssertFalse(man.playing)
    }

    func testIsLoadingReflectsState() {
        let man = MagicPlayMan()
        XCTAssertFalse(man.isLoading)
        man.setState(.loading(.connecting), reason: "test")
        XCTAssertTrue(man.isLoading)
        man.setState(.playing, reason: "test")
        XCTAssertFalse(man.isLoading)
    }

    func testIsCurrentAssetLikedReturnsFalseWhenNoURL() {
        let man = MagicPlayMan()
        XCTAssertFalse(man.isCurrentAssetLiked)
    }

    func testIsCurrentAssetLikedReturnsTrueWhenLiked() {
        let man = MagicPlayMan()
        let url = URL(fileURLWithPath: "/tmp/liked.mp3")
        man.setCurrentURL(url)
        man.setLikedAssets([url])
        XCTAssertTrue(man.isCurrentAssetLiked)
    }

    func testRemainingTime() {
        let man = MagicPlayMan()
        man.setDuration(100)
        man.setCurrentTime(30, reason: "test")
        XCTAssertEqual(man.remainingTime, 70)
    }

    func testRemainingTimeClampsToZero() {
        let man = MagicPlayMan()
        man.setDuration(100)
        man.setCurrentTime(150, reason: "test")
        XCTAssertEqual(man.remainingTime, 0)
    }

    func testSupportedFormats() {
        let man = MagicPlayMan()
        XCTAssertGreaterThanOrEqual(man.supportedFormats.count, 4)
    }

    func testCacheDirectoryIsInitiallyNil() {
        let man = MagicPlayMan()
        // Cache may be nil until initialized
        _ = man.cacheDirectory
    }

    // MARK: - Like Toggle

    func testToggleLikeWhenNotLiked() {
        let man = MagicPlayMan()
        let url = URL(fileURLWithPath: "/tmp/toggle.mp3")
        man.setCurrentURL(url)
        XCTAssertFalse(man.isCurrentAssetLiked)
        man.toggleLike()
        XCTAssertTrue(man.isCurrentAssetLiked)
    }

    func testToggleLikeWhenAlreadyLiked() {
        let man = MagicPlayMan()
        let url = URL(fileURLWithPath: "/tmp/toggle2.mp3")
        man.setCurrentURL(url)
        man.setLikedAssets([url])
        XCTAssertTrue(man.isCurrentAssetLiked)
        man.toggleLike()
        XCTAssertFalse(man.isCurrentAssetLiked)
    }

    // MARK: - Verbose Mode

    func testSetVerboseMode() {
        let man = MagicPlayMan()
        man.setVerboseMode(true)
        XCTAssertTrue(man.verbose)
        man.setVerboseMode(false)
        XCTAssertFalse(man.verbose)
    }

    // MARK: - Play Mode

    func testSetPlayModeChangesMode() {
        let man = MagicPlayMan()
        XCTAssertEqual(man.playMode, .sequence)
        man.setPlayMode(.shuffle)
        XCTAssertEqual(man.playMode, .shuffle)
    }

    func testChangePlayModeSetsMode() async throws {
        let man = MagicPlayMan()
        XCTAssertEqual(man.playMode, .sequence)
        man.changePlayMode(.shuffle)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(man.playMode, .shuffle)
    }

    // MARK: - Controls

    func testSetMuted() {
        let man = MagicPlayMan()
        XCTAssertFalse(man.player.isMuted)
        man.setMuted(true)
        XCTAssertTrue(man.player.isMuted)
        man.setMuted(false)
        XCTAssertFalse(man.player.isMuted)
    }

    func testSetVolumeNormalizesInput() {
        let man = MagicPlayMan()
        man.setVolume(-0.5)
        XCTAssertEqual(man.player.volume, 0)
        man.setVolume(0.75)
        XCTAssertEqual(man.player.volume, 0.75)
        man.setVolume(2.0)
        XCTAssertEqual(man.player.volume, 1.0)
    }

    func testSkipBackwardWithNoAsset() {
        let man = MagicPlayMan()
        man.skipBackward(10)
        // Should not crash
    }

    func testSkipForwardWithNoAsset() {
        let man = MagicPlayMan()
        man.skipForward(10)
        // Should not crash
    }

    func testPauseWithNoAsset() {
        let man = MagicPlayMan()
        man.pause(reason: "test")
        // Should not crash
    }

    func testPlayCurrentWithNoAsset() {
        let man = MagicPlayMan()
        man.playCurrent(reason: "test")
        // Should not crash
    }

    func testSetLikeWithNoAsset() {
        let man = MagicPlayMan()
        man.setLike(true, reason: "test")
        // Should not crash
    }

    func testToggleLikeWithNoAsset() {
        let man = MagicPlayMan()
        man.toggleLike()
        XCTAssertFalse(man.isCurrentAssetLiked)
    }

    func testToggleInIdleStateDoesNotChangeState() {
        let man = MagicPlayMan()
        man.setState(.idle, reason: "test")
        man.toggle(reason: "test")
        XCTAssertEqual(man.state, .idle)
    }

    func testToggleInFailedStateDoesNotChangeState() {
        let man = MagicPlayMan()
        man.setState(.failed(.noAsset), reason: "test")
        man.toggle(reason: "test")
        XCTAssertEqual(man.state, .failed(.noAsset))
    }

    func testNextWithNoAsset() {
        let man = MagicPlayMan()
        man.next()
        // Should not crash
    }

    func testPreviousWithNoAsset() {
        let man = MagicPlayMan()
        man.previous()
        // Should not crash
    }

    func testSeekWithNoAsset() {
        let man = MagicPlayMan()
        man.seek(time: 10, reason: "test")
        // Should not crash
    }

    func testSetMutedUnmuted() {
        let man = MagicPlayMan()
        man.setMuted(true)
        XCTAssertTrue(man.player.isMuted)
        man.setMuted(false)
        XCTAssertFalse(man.player.isMuted)
    }

    // MARK: - Subscription Events

    func testSubscribeReturnsID() {
        let man = MagicPlayMan()
        let id = man.subscribe(
            name: "test",
            onPlayModeChanged: { _ in }
        )
        XCTAssertNotEqual(id, UUID())
    }

    func testHasNavigationSubscribersIsFalseInitially() {
        let man = MagicPlayMan()
        XCTAssertFalse(man.events.hasNavigationSubscribers)
    }

    func testStateChangeNotification() async throws {
        let man = MagicPlayMan()
        var states: [PlaybackState] = []
        let id = man.subscribe(name: "test", onStateChanged: { state in
            states.append(state)
        })
        defer { man.unsubscribe(id) }

        man.setState(.playing, reason: "test")
        try await Task.sleep(nanoseconds: 10_000_000)
        man.setState(.paused, reason: "test")
        try await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(states, [.playing, .paused])
    }

    func testPlayModeChangeNotification() async throws {
        let man = MagicPlayMan()
        var modes: [PlaybackMode] = []
        let id = man.subscribe(name: "test", onPlayModeChanged: { mode in
            modes.append(mode)
        })
        defer { man.unsubscribe(id) }

        man.setPlayMode(.shuffle)
        try await Task.sleep(nanoseconds: 10_000_000)
        man.setPlayMode(.loop)
        try await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(modes, [.shuffle, .loop])
    }

    private static func makeSilentWAV() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100)!
        buffer.frameLength = 44_100
        try file.write(from: buffer)
        return url
    }

    private static func seek(_ player: AVPlayer, to seconds: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { continuation in
            player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600)) { finished in
                if finished {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: CancellationError())
                }
            }
        }
    }
}
