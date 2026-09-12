import Foundation
import Testing
@testable import ProviderPlayback

@MainActor
private final class StubPlaybackProvider: PlaybackProviding {
    var state: PlaybackStatus = .paused
    var currentURL: URL? = URL(fileURLWithPath: "/library/current.mp3")
    var currentTime: TimeInterval = 12
    var duration: TimeInterval = 48
    var progress: Double = 0.25
    var playMode: PlaybackMode = .shuffle
    var likedAssets: Set<URL> = [URL(fileURLWithPath: "/library/liked.mp3")]
    private(set) var playedURLs: [URL] = []

    var isPlaying: Bool { state.isPlaying }
    var hasAsset: Bool { currentURL != nil }

    func play(_ url: URL) async { playedURLs.append(url) }
    func pause() {}
    func toggle() {}
    func seek(toProgress progress: Double) {}
    func seek(toTime time: TimeInterval) {}
    func next() {}
    func previous() {}
    func setPlayMode(_ mode: PlaybackMode) {}
    func toggleCurrentLike() {}
    func togglePlayMode() {}
}

@MainActor
struct ProviderPlaybackTests {
    @Test
    func observerReceivesEventsAndStopsAfterCancellation() {
        let store = PlaybackObserverStore<Int>()
        var received: [Int] = []
        let handle = store.add { received.append($0) }

        store.send(1)
        #expect(received == [1])

        handle.cancel()
        store.send(2)
        #expect(received == [1])
    }

    @Test
    func observerCanCancelItselfWithoutSkippingOtherObservers() {
        let store = PlaybackObserverStore<Int>()
        var selfReceived: [Int] = []
        var otherReceived: [Int] = []
        var selfHandle: PlaybackObserverStoreHandle<Int>?
        selfHandle = store.add {
            selfReceived.append($0)
            selfHandle?.cancel()
        }
        let otherHandle = store.add { otherReceived.append($0) }

        store.send(1)
        store.send(2)
        selfHandle?.cancel()
        otherHandle.cancel()
        otherHandle.cancel()

        #expect(selfReceived == [1])
        #expect(otherReceived.count == 2)
    }

    @Test
    func snapshotDerivesAssetAndPlayingState() {
        let snapshot = PlaybackSnapshot(
            state: .playing,
            currentURL: URL(fileURLWithPath: "/tmp/track.mp3"),
            currentTime: 1,
            duration: 2,
            progress: 0.5,
            playMode: .sequence,
            likedAssets: []
        )

        #expect(snapshot.isPlaying)
        #expect(snapshot.hasAsset)
    }

    @Test
    func playbackStatusFlagsDistinguishLoadingAndDownloading() {
        #expect(!PlaybackStatus.idle.isPlaying)
        #expect(!PlaybackStatus.idle.isLoading)
        #expect(!PlaybackStatus.idle.isDownloading)

        #expect(PlaybackStatus.loading(.connecting).isLoading)
        #expect(!PlaybackStatus.loading(.connecting).isDownloading)
        #expect(PlaybackStatus.loading(.downloading(0.4)).isDownloading)
        #expect(!PlaybackStatus.loading(.downloading(0.4)).isPlaying)

        #expect(PlaybackStatus.playing.isPlaying)
        #expect(!PlaybackStatus.paused.isPlaying)
        #expect(!PlaybackStatus.stopped.isLoading)
        #expect(!PlaybackStatus.failed(.noAsset).isDownloading)
    }

    @Test
    func noOpObserverFallbackCanBeCancelledRepeatedly() {
        let provider = StubPlaybackProvider()
        let handle = provider.addObserver { _ in
            Issue.record("The default observer must not receive events")
        }

        #expect(handle is NoopPlaybackProvidingObserverHandle)
        handle.cancel()
        handle.cancel()
    }

    @Test
    func navigationFailurePreservesDirectionAndReason() {
        let failure = PlaybackNavigationFailure(direction: .next, reason: "No next track")

        #expect(failure.direction == .next)
        #expect(failure.reason == "No next track")
        #expect(PlaybackNavigationFailure(direction: .previous, reason: "Unavailable") != failure)
        #expect(PlaybackMode.allCases.map(\.rawValue) == ["sequence", "loop", "shuffle", "repeatAll"])
    }

    @Test
    func providerDefaultsBuildSnapshotAndForwardTimedPlay() async {
        let provider = StubPlaybackProvider()
        let snapshot = provider.snapshot
        let timedURL = URL(fileURLWithPath: "/library/timed.mp3")

        await provider.play(timedURL, startTime: 9)
        await provider.reset()

        #expect(snapshot.state == .paused)
        #expect(snapshot.currentURL == provider.currentURL)
        #expect(snapshot.currentTime == 12)
        #expect(snapshot.duration == 48)
        #expect(snapshot.progress == 0.25)
        #expect(snapshot.playMode == .shuffle)
        #expect(snapshot.likedAssets == provider.likedAssets)
        #expect(!snapshot.isPlaying)
        #expect(snapshot.hasAsset)
        #expect(provider.playedURLs == [timedURL])
        #expect(provider.state == .paused)
        #expect(provider.currentURL == URL(fileURLWithPath: "/library/current.mp3"))
    }
}
