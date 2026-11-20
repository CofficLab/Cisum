import XCTest
@testable import ProviderVideo

final class VideoTagSupportTests: XCTestCase {
    func testNormalizedTagsSplitsOnMultipleSeparators() {
        let tags = VideoTagSupport.normalizedTags(from: "旅行, 风景；影像;旅行")
        XCTAssertEqual(tags, ["旅行", "风景", "影像"])
    }

    func testNormalizedTagsDropsEmptyEntries() {
        let tags = VideoTagSupport.normalizedTags(from: " , ;\n ")
        XCTAssertTrue(tags.isEmpty)
    }

    func testEditableTextRoundTrip() {
        let tags = VideoTagSupport.normalizedTags(from: "a,b")
        XCTAssertEqual(VideoTagSupport.editableText(from: tags), "a, b")
    }
}

final class VideoPlaybackProgressTests: XCTestCase {
    func testFractionIsClamped() {
        let progress = VideoPlaybackProgress(position: 30, duration: 60)
        XCTAssertEqual(progress.fraction, 0.5, accuracy: 0.0001)
    }

    func testFractionIsZeroWhenDurationUnknown() {
        XCTAssertEqual(VideoPlaybackProgress(position: 30).fraction, 0)
    }
}

final class VideoFileSupportTests: XCTestCase {
    func testIsSupportedRecognizesCommonContainers() {
        XCTAssertTrue(VideoFileSupport.isSupported(URL(fileURLWithPath: "/tmp/a.mkv")))
        XCTAssertTrue(VideoFileSupport.isSupported(URL(fileURLWithPath: "/tmp/a.MP4")))
        XCTAssertFalse(VideoFileSupport.isSupported(URL(fileURLWithPath: "/tmp/a.txt")))
    }
}
