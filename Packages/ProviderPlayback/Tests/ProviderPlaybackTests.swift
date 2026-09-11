import Foundation
import Testing
@testable import ProviderPlayback

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
}
