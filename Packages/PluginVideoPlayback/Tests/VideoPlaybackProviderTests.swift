import XCTest
@testable import PluginVideoPlayback

final class VideoPlaybackProviderTests: XCTestCase {
    @MainActor
    func testInitialStateIsIdle() {
        let provider = VideoPlaybackProvider()
        XCTAssertEqual(provider.state, .idle)
        XCTAssertNil(provider.currentURL)
        XCTAssertFalse(provider.hasAsset)
        XCTAssertEqual(provider.progress, 0)
    }

    @MainActor
    func testObserverReceivesEvents() {
        let provider = VideoPlaybackProvider()
        let received = expectation(description: "observer receives state change")
        provider.addObserver { event in
            if case .stateChanged = event {
                received.fulfill()
            }
        }
        provider.play(URL(fileURLWithPath: "/tmp/does-not-exist.mp4"), startTime: nil)
        wait(for: [received], timeout: 2)
    }

    @MainActor
    func testStopClearsCurrentAsset() {
        let provider = VideoPlaybackProvider()
        provider.play(URL(fileURLWithPath: "/tmp/does-not-exist.mp4"), startTime: nil)
        provider.stop()
        XCTAssertNil(provider.currentURL)
        XCTAssertEqual(provider.state, .idle)
    }
}
