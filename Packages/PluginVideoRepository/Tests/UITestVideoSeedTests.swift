import AVFoundation
import XCTest
@testable import PluginVideoRepository

final class UITestVideoSeedTests: XCTestCase {
    func testRequestedNamesRequireUITestingAndSafeMP4Names() {
        let arguments = [
            "Cisum",
            "--cisum-ui-testing",
            "--cisum-ui-testing-seed-video",
            "Clip.mp4,../Escape.mp4,notes.txt",
        ]

        XCTAssertEqual(UITestVideoSeed.requestedFileNames(arguments: arguments), ["Clip.mp4"])
        XCTAssertTrue(UITestVideoSeed.requestedFileNames(arguments: ["Cisum", "--cisum-ui-testing-seed-video", "Clip.mp4"]).isEmpty)
    }

    func testGeneratedVideoHasReadableDurationAndVideoTrack() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("UITestVideoSeed-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: url) }

        try await UITestVideoSeed.makeVideo(at: url, duration: 1)

        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        XCTAssertEqual(CMTimeGetSeconds(duration), 1, accuracy: 0.1)
        XCTAssertEqual(videoTracks.count, 1)
    }
}
