import AVFoundation
import Combine
@testable import MagicPlayMan
import XCTest

// MARK: - MagicPlayMan Core Tests

final class MagicPlayManCoreTests: XCTestCase {
    func testMediaPickerAccessibilityLabelIncludesControlPurpose() {
        XCTAssertEqual(
            MediaPickerButtonAccessibilityPolicy.label(
                selectedName: "Track One",
                selectMediaText: "Select Media"
            ),
            "Select Media: Track One"
        )
        XCTAssertEqual(
            MediaPickerButtonAccessibilityPolicy.label(
                selectedName: "  ",
                selectMediaText: "Select Media"
            ),
            "Select Media"
        )
        XCTAssertEqual(
            MediaPickerButtonAccessibilityPolicy.label(
                selectedName: nil,
                selectMediaText: "选择媒体"
            ),
            "选择媒体"
        )
    }

    func testPlaybackEndNotificationMustBelongToCurrentItem() {
        let current = AVPlayerItem(url: URL(fileURLWithPath: "/tmp/current.mp3"))
        let stale = AVPlayerItem(url: URL(fileURLWithPath: "/tmp/stale.mp3"))

        XCTAssertTrue(MagicPlayMan.isPlaybackNotificationForCurrentItem(current, currentItem: current))
        XCTAssertFalse(MagicPlayMan.isPlaybackNotificationForCurrentItem(stale, currentItem: current))
        XCTAssertFalse(MagicPlayMan.isPlaybackNotificationForCurrentItem(nil, currentItem: current))
        XCTAssertFalse(MagicPlayMan.isPlaybackNotificationForCurrentItem(current, currentItem: nil))
        XCTAssertTrue(MagicPlayMan.isPlaybackEndNotificationForCurrentItem(current, currentItem: current))
        XCTAssertFalse(MagicPlayMan.isPlaybackEndNotificationForCurrentItem(stale, currentItem: current))
        XCTAssertFalse(MagicPlayMan.isPlaybackEndNotificationForCurrentItem(nil, currentItem: current))
        XCTAssertFalse(MagicPlayMan.isPlaybackEndNotificationForCurrentItem(current, currentItem: nil))
    }

    func testNowPlayingMetadataResultMustBelongToCurrentAsset() {
        let current = URL(fileURLWithPath: "/tmp/current.mp3")
        let stale = URL(fileURLWithPath: "/tmp/stale.mp3")

        XCTAssertTrue(MagicPlayMan.shouldApplyNowPlayingMetadataResult(requestedAsset: current, currentAsset: current))
        XCTAssertFalse(MagicPlayMan.shouldApplyNowPlayingMetadataResult(requestedAsset: stale, currentAsset: current))
        XCTAssertFalse(MagicPlayMan.shouldApplyNowPlayingMetadataResult(requestedAsset: current, currentAsset: nil))
    }

    func testAudioArtworkResultMustBelongToCurrentAsset() {
        let current = URL(fileURLWithPath: "/tmp/current.mp3")
        let stale = URL(fileURLWithPath: "/tmp/stale.mp3")

        XCTAssertTrue(AudioContentArtworkLoadPolicy.shouldApplyResult(requestedAsset: current, currentAsset: current))
        XCTAssertFalse(AudioContentArtworkLoadPolicy.shouldApplyResult(requestedAsset: stale, currentAsset: current))
    }

    func testRemoteCommandRegistrationReplacesExistingTargets() {
        XCTAssertFalse(MagicPlayMan.shouldReplaceRemoteCommandTargets(existingManagerCount: 0))
        XCTAssertTrue(MagicPlayMan.shouldReplaceRemoteCommandTargets(existingManagerCount: 1))
        XCTAssertTrue(MagicPlayMan.shouldReplaceRemoteCommandTargets(existingManagerCount: 3))
    }

    func testNowPlayingMetadataMatchesSymlinkedCurrentAsset() throws {
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

        XCTAssertTrue(MagicPlayMan.shouldApplyNowPlayingMetadataResult(
            requestedAsset: linkedAsset,
            currentAsset: realAsset
        ))
        XCTAssertTrue(AudioContentArtworkLoadPolicy.shouldApplyResult(
            requestedAsset: linkedAsset,
            currentAsset: realAsset
        ))
    }
}

// MARK: - Policy Tests

final class PolicyTests: XCTestCase {
    func testPlaybackRequestValidationRejectsMissingLocalFiles() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp3")

        XCTAssertEqual(
            MagicPlayManPlaybackRequestPolicy.basicValidationError(for: missing),
            .invalidAsset
        )
    }

    func testPlaybackRequestValidationRejectsUnsupportedFiles() throws {
        let unsupported = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")
        defer {
            try? FileManager.default.removeItem(at: unsupported)
        }

        try Data("not media".utf8).write(to: unsupported)

        XCTAssertEqual(
            MagicPlayManPlaybackRequestPolicy.basicValidationError(for: unsupported),
            .unsupportedFormat("txt")
        )
    }

    func testPlaybackRequestValidationAcceptsHLSStreams() {
        XCTAssertNil(MagicPlayManPlaybackRequestPolicy.basicValidationError(for: .sample_web_stream_basic))
        XCTAssertTrue(URL.sample_web_stream_basic.isVideo)
    }

    func testPlaybackRequestValidationAcceptsAudiobookFiles() throws {
        let audiobook = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4b")
        defer {
            try? FileManager.default.removeItem(at: audiobook)
        }

        try Data("audiobook".utf8).write(to: audiobook)

        XCTAssertNil(MagicPlayManPlaybackRequestPolicy.basicValidationError(for: audiobook))
        XCTAssertTrue(audiobook.isAudio)
    }

    // MARK: - Seek Policy

    func testSeekPolicyClampsInvalidAndOutOfRangeTimes() {
        XCTAssertEqual(MagicPlayManSeekPolicy.normalizedTime(-5, duration: 100), 0)
        XCTAssertEqual(MagicPlayManSeekPolicy.normalizedTime(120, duration: 100), 100)
        XCTAssertEqual(MagicPlayManSeekPolicy.normalizedTime(40, duration: 100), 40)
        XCTAssertEqual(MagicPlayManSeekPolicy.normalizedTime(.infinity, duration: 100), 0)
    }

    func testSeekPolicyAllowsPositiveTimeWhenDurationIsUnknown() {
        XCTAssertEqual(MagicPlayManSeekPolicy.normalizedTime(30, duration: 0), 30)
        XCTAssertEqual(MagicPlayManSeekPolicy.normalizedTime(30, duration: .nan), 30)
    }

    func testSeekPolicyNormalizesOptionalStartTime() {
        XCTAssertNil(MagicPlayManSeekPolicy.normalizedStartTime(nil, duration: 100))
        XCTAssertNil(MagicPlayManSeekPolicy.normalizedStartTime(-5, duration: 100))
        XCTAssertNil(MagicPlayManSeekPolicy.normalizedStartTime(.nan, duration: 100))
        XCTAssertNil(MagicPlayManSeekPolicy.normalizedStartTime(.infinity, duration: 100))
        XCTAssertEqual(MagicPlayManSeekPolicy.normalizedStartTime(120, duration: 100), 100)
        XCTAssertEqual(MagicPlayManSeekPolicy.normalizedStartTime(30, duration: 0), 30)
    }

    // MARK: - Control Input Policy

    func testControlInputPolicyNormalizesVolume() {
        XCTAssertEqual(MagicPlayManControlInputPolicy.normalizedVolume(-0.25), 0)
        XCTAssertEqual(MagicPlayManControlInputPolicy.normalizedVolume(0.4), 0.4)
        XCTAssertEqual(MagicPlayManControlInputPolicy.normalizedVolume(1.5), 1)
        XCTAssertEqual(MagicPlayManControlInputPolicy.normalizedVolume(.nan), 0)
        XCTAssertEqual(MagicPlayManControlInputPolicy.normalizedVolume(.infinity), 0)
    }

    func testControlInputPolicyNormalizesSkipIntervals() {
        XCTAssertEqual(MagicPlayManControlInputPolicy.normalizedSkipInterval(-5), 0)
        XCTAssertEqual(MagicPlayManControlInputPolicy.normalizedSkipInterval(15), 15)
        XCTAssertEqual(MagicPlayManControlInputPolicy.normalizedSkipInterval(.nan), 0)
        XCTAssertEqual(MagicPlayManControlInputPolicy.normalizedSkipInterval(.infinity), 0)
    }

    // MARK: - Playback Time Policy

    func testPlaybackTimePolicyRejectsInvalidTimes() {
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedCurrentTime(.nan), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedCurrentTime(.infinity), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedCurrentTime(-5), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedCurrentTime(42), 42)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedCurrentTime(120, duration: 100), 100)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedCurrentTime(120, duration: 0), 120)
    }

    func testPlaybackTimePolicyRejectsInvalidDurations() {
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedDuration(.nan), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedDuration(.infinity), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedDuration(-5), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedDuration(42), 42)
    }

    func testPlaybackTimePolicyClampsProgress() {
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedUnitProgress(1.4), 1)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedUnitProgress(-0.2), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedUnitProgress(.nan), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedProgress(currentTime: 50, duration: 100), 0.5)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedProgress(currentTime: 120, duration: 100), 1)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedProgress(currentTime: -10, duration: 100), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedProgress(currentTime: .nan, duration: 100), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedProgress(currentTime: 10, duration: 0), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedProgress(currentTime: 10, duration: .infinity), 0)
    }

    func testPlaybackTimePolicyRestartsWhenAtOrPastEnd() {
        XCTAssertTrue(MagicPlayManPlaybackTimePolicy.shouldRestartFromBeginning(currentTime: 100, duration: 100))
        XCTAssertTrue(MagicPlayManPlaybackTimePolicy.shouldRestartFromBeginning(currentTime: 100.01, duration: 100))
        XCTAssertFalse(MagicPlayManPlaybackTimePolicy.shouldRestartFromBeginning(currentTime: 99.9, duration: 100))
        XCTAssertFalse(MagicPlayManPlaybackTimePolicy.shouldRestartFromBeginning(currentTime: 10, duration: 0))
        XCTAssertFalse(MagicPlayManPlaybackTimePolicy.shouldRestartFromBeginning(currentTime: .nan, duration: 100))
    }

    // MARK: - Time Update Policy

    func testTimeUpdatePolicyNormalizesInvalidPayloadValues() {
        let payload = MagicPlayManTimeUpdatePolicy.normalizedPayload(from: [
            "currentTime": TimeInterval.nan,
            "progress": Double.infinity,
        ])

        XCTAssertEqual(payload?.0, 0)
        XCTAssertEqual(payload?.1, 0)

        let clampedPayload = MagicPlayManTimeUpdatePolicy.normalizedPayload(from: [
            "currentTime": TimeInterval(-4),
            "progress": 1.4,
        ])

        XCTAssertEqual(clampedPayload?.0, 0)
        XCTAssertEqual(clampedPayload?.1, 1)
        XCTAssertNil(MagicPlayManTimeUpdatePolicy.normalizedPayload(from: ["currentTime": TimeInterval(12)]))
    }
}
