import AVFoundation
@testable import MagicPlayMan
import XCTest

// MARK: - Download Policy Tests

final class DownloadPolicyTests: XCTestCase {
    func testResultMustBelongToCurrentAsset() {
        let current = URL(fileURLWithPath: "/tmp/current.mp3")
        let stale = URL(fileURLWithPath: "/tmp/stale.mp3")

        XCTAssertTrue(MagicPlayManDownloadRequestPolicy.shouldApplyResult(
            requestedAsset: current,
            currentAsset: current
        ))
        XCTAssertFalse(MagicPlayManDownloadRequestPolicy.shouldApplyResult(
            requestedAsset: stale,
            currentAsset: current
        ))
        XCTAssertFalse(MagicPlayManDownloadRequestPolicy.shouldApplyResult(
            requestedAsset: current,
            currentAsset: nil
        ))
        XCTAssertTrue(MagicPlayManDownloadRequestPolicy.shouldFinishDownload(
            requestedAsset: current,
            currentAsset: current
        ))
        XCTAssertFalse(MagicPlayManDownloadRequestPolicy.shouldFinishDownload(
            requestedAsset: stale,
            currentAsset: current
        ))
        XCTAssertFalse(MagicPlayManDownloadRequestPolicy.shouldFinishDownload(
            requestedAsset: current,
            currentAsset: nil
        ))
    }

    func testResultMatchesSymlinkedCurrentAsset() throws {
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

        XCTAssertTrue(MagicPlayManDownloadRequestPolicy.shouldApplyResult(
            requestedAsset: linkedAsset,
            currentAsset: realAsset
        ))
        XCTAssertTrue(MagicPlayManDownloadRequestPolicy.shouldFinishDownload(
            requestedAsset: linkedAsset,
            currentAsset: realAsset
        ))
    }

    func testObserverCleanupOnlyUsesMatchingRequest() {
        let requested = URL(fileURLWithPath: "/tmp/requested.mp3")
        let other = URL(fileURLWithPath: "/tmp/other.mp3")

        XCTAssertTrue(MagicPlayManDownloadObserverPolicy.shouldUseObserver(
            requestedAsset: requested,
            observedAsset: requested
        ))
        XCTAssertFalse(MagicPlayManDownloadObserverPolicy.shouldUseObserver(
            requestedAsset: requested,
            observedAsset: other
        ))
        XCTAssertFalse(MagicPlayManDownloadObserverPolicy.shouldUseObserver(
            requestedAsset: requested,
            observedAsset: nil
        ))
    }

    func testObserverCleanupMatchesSymlinkedRequest() throws {
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

        XCTAssertTrue(MagicPlayManDownloadObserverPolicy.shouldUseObserver(
            requestedAsset: linkedAsset,
            observedAsset: realAsset
        ))
    }

    func testRemoteAssetsRequireExactURLIdentity() throws {
        let first = try XCTUnwrap(URL(string: "https://example.com/audio/track.mp3"))
        let second = try XCTUnwrap(URL(string: "https://cdn.example.com/audio/track.mp3"))

        XCTAssertTrue(MagicPlayManDownloadRequestPolicy.shouldApplyResult(
            requestedAsset: first,
            currentAsset: first
        ))
        XCTAssertFalse(MagicPlayManDownloadRequestPolicy.shouldApplyResult(
            requestedAsset: first,
            currentAsset: second
        ))
    }
}
