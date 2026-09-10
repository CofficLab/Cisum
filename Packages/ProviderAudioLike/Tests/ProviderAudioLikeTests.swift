import Foundation
import Testing
@testable import ProviderAudioLike

@Test
func audioLikeItemExposesStableTransportIdentity() {
    let item = AudioLikeItem(
        audioId: "audio-id",
        url: URL(string: "file:///tmp/audio.mp3"),
        title: "Audio",
        liked: true
    )

    #expect(item.id == "audio-id")
    #expect(item.liked)
}
