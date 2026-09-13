import Foundation
@testable import MagicPlayMan
import XCTest

// MARK: - Playback Time Policy Tests

/// 覆盖 `MagicPlayManPlaybackTimePolicy` 的数值规范化逻辑：
/// NaN/Infinity 输入、越界 clamp、无 duration 回退、结尾判定。
final class PlaybackTimePolicyTests: XCTestCase {
    // MARK: normalizedDuration

    func testNormalizedDurationRejectsNonFiniteValues() {
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedDuration(.nan), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedDuration(.infinity), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedDuration(-.infinity), 0)
    }

    func testNormalizedDurationClampsNegativeValues() {
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedDuration(-5), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedDuration(0), 0)
    }

    func testNormalizedDurationKeepsPositiveValues() {
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedDuration(120), 120)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedDuration(0.5), 0.5)
    }

    // MARK: normalizedUnitProgress

    func testNormalizedUnitProgressRejectsNonFiniteValues() {
        // 非有限输入统一按 0 处理（实现：progress.isFinite ? progress : 0）
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedUnitProgress(.nan), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedUnitProgress(.infinity), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedUnitProgress(-.infinity), 0)
    }

    func testNormalizedUnitProgressClampsOutOfRange() {
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedUnitProgress(-0.25), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedUnitProgress(1.5), 1)
    }

    func testNormalizedUnitProgressKeepsInRange() {
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedUnitProgress(0), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedUnitProgress(0.42), 0.42)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedUnitProgress(1), 1)
    }

    // MARK: normalizedCurrentTime

    func testNormalizedCurrentTimeRejectsNonFiniteValues() {
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedCurrentTime(.nan), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedCurrentTime(-.infinity), 0)
    }

    func testNormalizedCurrentTimeClampsNegativeWithoutDuration() {
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedCurrentTime(-10), 0)
    }

    func testNormalizedCurrentTimeKeepsValueWithoutDuration() {
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedCurrentTime(30), 30)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedCurrentTime(0), 0)
    }

    func testNormalizedCurrentTimeClampsToDuration() {
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedCurrentTime(200, duration: 120), 120)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedCurrentTime(-5, duration: 120), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedCurrentTime(30, duration: 120), 30)
    }

    func testNormalizedCurrentTimeIgnoresInvalidDuration() {
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedCurrentTime(30, duration: .nan), 30)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedCurrentTime(30, duration: -1), 30)
    }

    // MARK: normalizedProgress

    func testNormalizedProgressRejectsInvalidInputs() {
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedProgress(currentTime: .nan, duration: 120), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedProgress(currentTime: 30, duration: .nan), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedProgress(currentTime: 30, duration: 0), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedProgress(currentTime: 30, duration: -1), 0)
    }

    func testNormalizedProgressComputesRatio() {
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedProgress(currentTime: 30, duration: 120), 0.25, accuracy: 0.0001)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedProgress(currentTime: 0, duration: 120), 0)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedProgress(currentTime: 120, duration: 120), 1)
    }

    func testNormalizedProgressClampsOutOfRange() {
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedProgress(currentTime: 240, duration: 120), 1)
        XCTAssertEqual(MagicPlayManPlaybackTimePolicy.normalizedProgress(currentTime: -30, duration: 120), 0)
    }

    // MARK: shouldRestartFromBeginning

    func testShouldRestartFromBeginningRejectsInvalidInputs() {
        XCTAssertFalse(MagicPlayManPlaybackTimePolicy.shouldRestartFromBeginning(currentTime: .nan, duration: 120))
        XCTAssertFalse(MagicPlayManPlaybackTimePolicy.shouldRestartFromBeginning(currentTime: 30, duration: .nan))
        XCTAssertFalse(MagicPlayManPlaybackTimePolicy.shouldRestartFromBeginning(currentTime: 30, duration: 0))
        XCTAssertFalse(MagicPlayManPlaybackTimePolicy.shouldRestartFromBeginning(currentTime: 30, duration: -1))
    }

    func testShouldRestartFromBeginningOnlyWhenFinished() {
        XCTAssertFalse(MagicPlayManPlaybackTimePolicy.shouldRestartFromBeginning(currentTime: 30, duration: 120))
        XCTAssertFalse(MagicPlayManPlaybackTimePolicy.shouldRestartFromBeginning(currentTime: 119, duration: 120))
        XCTAssertTrue(MagicPlayManPlaybackTimePolicy.shouldRestartFromBeginning(currentTime: 120, duration: 120))
        XCTAssertTrue(MagicPlayManPlaybackTimePolicy.shouldRestartFromBeginning(currentTime: 300, duration: 120))
    }
}

// MARK: - Play Mode Surface Tests

@MainActor
final class PlayModeSurfaceTests: XCTestCase {
    func testTogglePlayModeCyclesForward() async throws {
        let man = MagicPlayMan()
        XCTAssertEqual(man.playMode, .sequence)

        // changePlayMode 内部经 Task 异步落盘，需等待一次 runloop 让 Task 执行。
        func toggleAndWait() async throws {
            man.togglePlayMode()
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        try await toggleAndWait()
        XCTAssertEqual(man.playMode, .loop)
        try await toggleAndWait()
        XCTAssertEqual(man.playMode, .shuffle)
        try await toggleAndWait()
        XCTAssertEqual(man.playMode, .repeatAll)
        try await toggleAndWait()
        XCTAssertEqual(man.playMode, .sequence)
    }

    func testPlayModeDisplayNameReflectsCurrentMode() {
        let man = MagicPlayMan()
        man.setPlayMode(.shuffle)
        XCTAssertEqual(man.playModeDisplayName, MagicPlayMode.shuffle.displayName)
        XCTAssertEqual(man.playModeIcon, MagicPlayMode.shuffle.icon)
    }
}

// MARK: - MagicAsset Semantics

final class MagicAssetTests: XCTestCase {
    func testMetadataDefaults() {
        let metadata = MagicAsset.Metadata(title: "Only Title")
        XCTAssertEqual(metadata.title, "Only Title")
        XCTAssertNil(metadata.artist)
        XCTAssertNil(metadata.album)
        XCTAssertNil(metadata.artwork)
        XCTAssertEqual(metadata.duration, 0)
    }

    func testMetadataFullInit() {
        let metadata = MagicAsset.Metadata(
            title: "Title",
            artist: "Artist",
            album: "Album",
            duration: 180
        )
        XCTAssertEqual(metadata.title, "Title")
        XCTAssertEqual(metadata.artist, "Artist")
        XCTAssertEqual(metadata.album, "Album")
        XCTAssertEqual(metadata.duration, 180)
    }

    func testAssetEqualityComparesIdentity() {
        let url = URL(fileURLWithPath: "/tmp/a.mp3")
        let a = MagicAsset(url: url, metadata: .init(title: "A"))
        let b = MagicAsset(url: url, metadata: .init(title: "B"))
        // Equatable 只比较 id，两个实例即使元数据相同也不相等。
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a, a)
    }

    func testAssetComputedProperties() {
        let asset = MagicAsset(
            url: URL(fileURLWithPath: "/tmp/a.mp3"),
            metadata: .init(title: "Title", artist: "Artist", album: "Album")
        )
        XCTAssertEqual(asset.title, "Title")
        XCTAssertEqual(asset.artist, "Artist")
        XCTAssertEqual(asset.album, "Album")
    }
}
