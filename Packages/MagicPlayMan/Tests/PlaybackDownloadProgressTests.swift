import AVFoundation
@testable import MagicPlayMan
import MagicKit
import XCTest

/// 顶部 Hero「xx% 正在下载」的进度发布链路契约。
///
/// 复现的缺陷现象：iCloud 下载期间，顶部播放器一直显示「0% 正在下载 0%」，
/// 而仓库列表的下载进度环在正常前进（8% …）。顶部进度完全依赖
/// `play()` 内的 progressTask 把 `downloader.downloadProgress(url)` 的
/// 上升值发布为 `.loading(.downloading(progress))` 状态事件，
/// 该链路一旦停摆或被 0 覆盖，Hero 就会永远卡在 0%。
@MainActor
final class PlaybackDownloadProgressTests: XCTestCase {
    override func tearDown() {
        ICloudDownloadControl.shared.reset()
        super.tearDown()
    }

    /// 下载等待期间，播放层必须向订阅者发布非零、随下载推进的进度。
    ///
    /// 期望观测到的进度序列（stub: succeeds(afterPolls: 8)）：
    /// downloading(0) → 下载推进后出现 > 0 的中间值 → 完成。
    /// 若序列里最大值恒为 0，即复现了「顶部进度一直 0%」的缺陷。
    func testDownloadProgressRisesWhileWaitingForICloudContent() async throws {
        let url = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let stub = StubUbiquitousItemDownloader(behavior: .succeeds(afterPolls: 8))
        ICloudDownloadControl.shared.override(stub)
        ICloudDownloadControl.shared.overrideTimeout(15)

        let man = MagicPlayMan()
        var observedProgresses: [Double] = []
        let handle = man.events.onStateChanged.sink { state in
            if case let .loading(.downloading(progress)) = state {
                observedProgresses.append(progress)
            }
        }
        defer { handle.cancel() }

        await man.play(url, reason: "downloadProgress.repro")

        let maxProgress = observedProgresses.max() ?? 0
        XCTAssertGreaterThan(
            observedProgresses.count, 1,
            "下载期间应持续发布下载状态，实际仅 \(observedProgresses.count) 次：\(observedProgresses)"
        )
        XCTAssertGreaterThan(
            maxProgress, 0,
            "下载推进后未发布任何非零进度，顶部 Hero 会一直显示 0%（观测序列：\(observedProgresses)）"
        )
    }

    /// 下载等待期间 UI 层可能重复触发 play（如列表 selection 回写同一曲目），
    /// 进度发布不得因为请求代际切换而永久停在 0。
    func testRepeatedPlayRequestStillPublishesProgress() async throws {
        let url = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let stub = StubUbiquitousItemDownloader(behavior: .succeeds(afterPolls: 10))
        ICloudDownloadControl.shared.override(stub)
        ICloudDownloadControl.shared.overrideTimeout(15)

        let man = MagicPlayMan()
        var observedProgresses: [Double] = []
        let handle = man.events.onStateChanged.sink { state in
            if case let .loading(.downloading(progress)) = state {
                observedProgresses.append(progress)
            }
        }
        defer { handle.cancel() }

        let firstPlay = Task { await man.play(url, reason: "downloadProgress.first") }
        try await Task.sleep(nanoseconds: 600_000_000)

        // 模拟下载途中 UI 再次触发同一资源的播放请求
        await man.play(url, reason: "downloadProgress.second")
        await firstPlay.value

        let maxProgress = observedProgresses.max() ?? 0
        XCTAssertGreaterThan(
            maxProgress, 0,
            "重复播放请求打断了进度发布，顶部 Hero 会一直显示 0%（观测序列：\(observedProgresses)）"
        )
    }

    // MARK: - Progress source merging

    /// 复现缺陷：顶部进度有两个来源——
    /// ① 轮询源：URL 资源键（`NSURLUbiquitousItemPercentDownloadedKey` + allocatedSize
    ///    兜底），生产环境对 dataless 文件长期读到 0；
    /// ② 事件源：`GlobalDownloadMonitor` 的 `NSMetadataItem` percent key——
    ///    这正是仓库列表进度环（8%）的数据源。
    /// 两源并联时，任何一源读到 0 都**不得**把另一源已发布的真实进度覆盖回 0%，
    /// 否则顶部 Hero 就会呈现用户报告的「一直 0%」。
    func testPollingZeroNeverRegressesPublishedProgress() {
        // 事件源发布了 8%，轮询源随后读到 0 → 必须保持 8%
        XCTAssertEqual(MagicPlayManDownloadProgressPolicy.merged(current: 0.08, incoming: 0), 0.08)
        // 轮询源推进到 30%，事件源回 0 → 取更高的 30%
        XCTAssertEqual(MagicPlayManDownloadProgressPolicy.merged(current: 0.08, incoming: 0.3), 0.3)
        // 初始态无进度，任一源给出有效值都要采纳
        XCTAssertEqual(MagicPlayManDownloadProgressPolicy.merged(current: 0, incoming: 0.08), 0.08)
        // 非法值按 0 处理，不得回退已发布进度
        XCTAssertEqual(MagicPlayManDownloadProgressPolicy.merged(current: 0.4, incoming: .nan), 0.4)
        // 越界值归一化
        XCTAssertEqual(MagicPlayManDownloadProgressPolicy.merged(current: 0, incoming: 1.5), 1)
        XCTAssertEqual(MagicPlayManDownloadProgressPolicy.merged(current: 0, incoming: -0.2), 0)
    }

    // MARK: - Helpers

    /// 写入一个真实存在的本地文件，确保通过播放前的基础校验；
    /// 是否「在下载」由注入的 stub 网关决定。
    private func makeTemporaryAudioFile() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlaybackDownloadProgressTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("track.mp3")
        try Data(repeating: 1, count: 1024).write(to: file)
        return file
    }
}
