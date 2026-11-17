import MagicKit
import MagicPlayMan
@testable import PluginPlayBack
import ProviderPlayback
import XCTest

/// Provider 边界的载入控制契约：取消与重试必须原样转发到引擎。
///
/// 引擎内部的取消/重试语义已由 `PlaybackICloudCancellationTests` 覆盖，
/// 这里验证 UI 依赖的这一层没有丢信息：取消后 Provider 停在 `.stopped`
/// 且不发布失败，重试复用原请求的起始位置与自动播放语义。
@MainActor
final class PlaybackLoadControlProviderTests: XCTestCase {
    override func tearDown() {
        ICloudDownloadControl.shared.reset()
        super.tearDown()
    }

    func testCancelPendingLoadStopsQuietlyAndKeepsAsset() async throws {
        let url = try Self.makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        ICloudDownloadControl.shared.override(
            StubUbiquitousItemDownloader(behavior: .neverCompletes)
        )
        ICloudDownloadControl.shared.overrideTimeout(30)

        let provider = PlaybackProvider(playback: MagicPlayMan())
        var observed: [PlaybackStatus] = []
        let handle = provider.addObserver { event in
            if case let .stateChanged(state) = event {
                observed.append(state)
            }
        }
        defer { handle.cancel() }

        let playTask = Task { await provider.play(url) }

        let reachedDownloading = await Self.waitUntil { provider.state.isDownloading }
        XCTAssertTrue(reachedDownloading, "未进入下载态，当前状态：\(provider.state)")
        XCTAssertEqual(provider.currentURL, url)

        provider.cancelPendingLoad()
        await playTask.value

        XCTAssertEqual(provider.state, .stopped, "取消后应安静停在 stopped")
        XCTAssertEqual(provider.currentURL, url, "取消不得清掉用户选中的资源")
        XCTAssertFalse(
            observed.contains(where: Self.isICloudFailure),
            "取消被 Provider 当成了下载失败：\(observed)"
        )
    }

    func testCancelPendingLoadIsNoOpWhenIdle() {
        let provider = PlaybackProvider(playback: MagicPlayMan())

        provider.cancelPendingLoad()

        XCTAssertEqual(provider.state, .idle)
    }

    func testRetryLastFailedLoadReplaysThroughProvider() async throws {
        let url = try Self.makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        ICloudDownloadControl.shared.override(
            StubUbiquitousItemDownloader(behavior: .startFails(message: "network offline"))
        )
        ICloudDownloadControl.shared.overrideTimeout(1)

        let provider = PlaybackProvider(playback: MagicPlayMan())

        await provider.play(url, startTime: 12)

        guard case .failed(.iCloudDownloadFailed) = provider.state else {
            return XCTFail("首次请求应失败于 iCloud，当前状态：\(provider.state)")
        }

        let succeedingStub = StubUbiquitousItemDownloader(behavior: .succeeds(afterPolls: 2))
        ICloudDownloadControl.shared.override(succeedingStub)
        ICloudDownloadControl.shared.overrideTimeout(2)

        var observed: [PlaybackStatus] = []
        let handle = provider.addObserver { event in
            if case let .stateChanged(state) = event {
                observed.append(state)
            }
        }
        defer { handle.cancel() }

        await provider.retryLastFailedLoad()

        XCTAssertGreaterThanOrEqual(
            succeedingStub.startDownloadCallCount, 1,
            "重试没有经 Provider 重新发起下载"
        )
        XCTAssertTrue(
            observed.contains(where: \.isDownloading),
            "重试没有重新进入下载态：\(observed)"
        )
        XCTAssertFalse(
            observed.contains(where: Self.isICloudFailure),
            "重试后仍发布 iCloud 失败：\(observed)"
        )
        XCTAssertEqual(provider.currentURL, url, "重试后未恢复到原资源")
    }

    // MARK: - Helpers

    private static func isICloudFailure(_ state: PlaybackStatus) -> Bool {
        if case .failed(.iCloudDownloadFailed) = state { return true }
        return false
    }

    private static func waitUntil(
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

    /// 写入一个真实存在的本地文件以通过播放前的基础校验；
    /// 是否「在下载」完全由注入的 stub 网关决定。
    private static func makeTemporaryAudioFile() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlaybackLoadControlProviderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("chapter.mp3")
        try Data(repeating: 1, count: 1024).write(to: file)
        return file
    }
}
