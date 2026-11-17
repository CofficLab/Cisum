import AVFoundation
import Combine
import XCTest
@testable import MagicPlayMan
import MagicKit

/// iCloud 载入等待的取消与重试契约。
///
/// 重点：
/// - 取消等待不是失败（#44）：不得发布 `.failed(.iCloudDownloadFailed)`；
/// - 取消保留用户选的资源，只把状态落到 `.stopped`；
/// - 重试必须复用原始请求的 `startTime` / `autoPlay`。
@MainActor
final class PlaybackICloudCancellationTests: XCTestCase {
    override func tearDown() {
        ICloudDownloadControl.shared.reset()
        super.tearDown()
    }

    // MARK: - Cancel

    func testCancelPendingLoadEndsQuietlyAndKeepsSelection() async throws {
        let (url, folder) = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: folder) }

        ICloudDownloadControl.shared.override(
            StubUbiquitousItemDownloader(behavior: .neverCompletes)
        )
        ICloudDownloadControl.shared.overrideTimeout(30)

        let man = MagicPlayMan()
        var observed: [PlaybackState] = []
        let handle = man.events.onStateChanged.sink { observed.append($0) }
        defer { handle.cancel() }

        let playTask = Task {
            await man.play(url, autoPlay: false, startTime: 12, reason: "cancel.test")
        }

        let reachedDownloading = await waitUntil { man.state.isDownloading }
        XCTAssertTrue(reachedDownloading, "未进入下载态，当前状态：\(man.state)")

        man.cancelPendingLoad(reason: "cancel.test.action")
        await playTask.value

        XCTAssertEqual(man.state, .stopped, "取消后应安静停在 stopped")
        XCTAssertEqual(man.currentURL, url, "取消不得清掉用户选中的资源")
        XCTAssertFalse(
            observed.contains { $0.isICloudDownloadFailed },
            "取消被当成了下载失败：\(observed)"
        )
    }

    func testCancelPendingLoadIsNoOpWhenNotDownloading() {
        let man = MagicPlayMan()

        man.cancelPendingLoad(reason: "cancel.idle")

        XCTAssertEqual(man.state, .idle)
    }

    /// #44 回归：调用方 Task 被取消，不得呈现为 iCloud 下载失败。
    func testCancellingPlayTaskDoesNotBecomeFailure() async throws {
        let (url, folder) = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: folder) }

        ICloudDownloadControl.shared.override(
            StubUbiquitousItemDownloader(behavior: .neverCompletes)
        )
        ICloudDownloadControl.shared.overrideTimeout(30)

        let man = MagicPlayMan()
        var observed: [PlaybackState] = []
        let handle = man.events.onStateChanged.sink { observed.append($0) }
        defer { handle.cancel() }

        let playTask = Task {
            await man.play(url, autoPlay: false, reason: "externalCancel.test")
        }

        let reachedDownloading = await waitUntil { man.state.isDownloading }
        XCTAssertTrue(reachedDownloading, "未进入下载态，当前状态：\(man.state)")

        playTask.cancel()
        await playTask.value

        XCTAssertEqual(man.state, .stopped, "外部取消应安静结束，而不是失败")
        XCTAssertFalse(
            observed.contains { $0.isICloudDownloadFailed },
            "CancellationError 被归类为 iCloud 失败：\(observed)"
        )
    }

    // MARK: - Retry

    func testRetryReplaysLastRequest() async throws {
        let (url, folder) = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: folder) }

        ICloudDownloadControl.shared.override(
            StubUbiquitousItemDownloader(behavior: .startFails(message: "network offline"))
        )
        ICloudDownloadControl.shared.overrideTimeout(1)

        let man = MagicPlayMan()
        await man.play(url, autoPlay: false, startTime: 12, reason: "retry.first")

        guard case .failed(.iCloudDownloadFailed) = man.state else {
            return XCTFail("首次请求应失败于 iCloud，当前状态：\(man.state)")
        }
        XCTAssertEqual(man.lastPlayRequest?.startTime, 12)
        XCTAssertEqual(man.lastPlayRequest?.autoPlay, false)
        XCTAssertEqual(man.lastPlayRequest?.url, url)

        let succeedingStub = StubUbiquitousItemDownloader(behavior: .succeeds(afterPolls: 2))
        ICloudDownloadControl.shared.override(succeedingStub)
        ICloudDownloadControl.shared.overrideTimeout(2)

        var observed: [PlaybackState] = []
        let handle = man.events.onStateChanged.sink { observed.append($0) }
        defer { handle.cancel() }

        await man.retryLastFailedLoad(reason: "retry.action")

        XCTAssertGreaterThanOrEqual(
            succeedingStub.startDownloadCallCount, 1,
            "重试没有重新发起下载"
        )
        XCTAssertTrue(
            observed.contains { $0.isDownloading },
            "重试没有重新进入下载态：\(observed)"
        )
        XCTAssertFalse(
            man.state.isICloudDownloadFailed,
            "重试后仍停留在 iCloud 失败态：\(man.state)"
        )
        XCTAssertEqual(man.lastPlayRequest?.startTime, 12, "重试丢失了原始起始位置")
        XCTAssertEqual(man.lastPlayRequest?.autoPlay, false, "重试丢失了原始 autoPlay 语义")
    }

    // MARK: - Helpers

    private func waitUntil(
        timeout: TimeInterval = 3,
        _ condition: @MainActor () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return condition()
    }

    /// 写入一个真实存在的本地文件，确保通过播放前的基础校验；
    /// 是否「在下载」由注入的 stub 网关决定。
    private func makeTemporaryAudioFile() throws -> (url: URL, folder: URL) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlaybackICloudCancellationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("chapter.mp3")
        try Data(repeating: 1, count: 1024).write(to: file)
        return (file, folder)
    }
}