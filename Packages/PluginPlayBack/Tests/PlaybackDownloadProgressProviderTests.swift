import MagicKit
import MagicPlayMan
@testable import PluginPlayBack
import ProviderPlayback
import XCTest

/// 顶部 Hero「xx% 正在下载」的事件桥接契约（Provider 层）。
///
/// Hero 显示的进度链：引擎 state → `PlaybackProvider` `.stateChanged` 事件
/// → `PlaybackHeroObserver` → Hero 文案。本测试在 Provider 边界复现
/// 「顶部进度一直 0%」缺陷：下载等待期间，Provider 的观察者必须收到
/// 随下载推进而上升的 downloading 进度；若序列恒为 0，Hero 即卡在 0%。
@MainActor
final class PlaybackDownloadProgressProviderTests: XCTestCase {
    override func tearDown() {
        ICloudDownloadControl.shared.reset()
        super.tearDown()
    }

    func testProviderPublishesRisingDownloadProgressToObservers() async throws {
        let url = try Self.makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        // stub：前 8 次探测视为未下载，随后完成；期间进度随探测推进。
        ICloudDownloadControl.shared.override(StubUbiquitousItemDownloader(behavior: .succeeds(afterPolls: 8)))
        ICloudDownloadControl.shared.overrideTimeout(15)

        let provider = PlaybackProvider(playback: MagicPlayMan())
        var observedProgresses: [Double] = []
        let handle = provider.addObserver { event in
            guard case let .stateChanged(state) = event,
                  case let .loading(.downloading(progress)) = state else { return }
            observedProgresses.append(progress)
        }
        defer { handle.cancel() }

        await provider.play(url)

        let maxProgress = observedProgresses.max() ?? 0
        XCTAssertGreaterThan(
            observedProgresses.count, 1,
            "Provider 在下载期间未持续转发下载状态，Hero 无从更新：\(observedProgresses)"
        )
        XCTAssertGreaterThan(
            maxProgress, 0,
            "Provider 转发的下载进度恒为 0，顶部 Hero 会一直显示「0% 正在下载」（观测序列：\(observedProgresses)）"
        )
    }

    /// Hero 状态文案与进度必须来自同一个状态值，避免「文案 8%、圆环 0%」的分裂。
    func testProviderStateTextMatchesPublishedProgress() async throws {
        let url = try Self.makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        ICloudDownloadControl.shared.override(StubUbiquitousItemDownloader(behavior: .succeeds(afterPolls: 6)))
        ICloudDownloadControl.shared.overrideTimeout(15)

        let provider = PlaybackProvider(playback: MagicPlayMan())

        var lastState: PlaybackStatus?
        let handle = provider.addObserver { event in
            if case let .stateChanged(state) = event {
                lastState = state
            }
        }
        defer { handle.cancel() }

        await provider.play(url)

        guard let lastState, case let .loading(.downloading(progress)) = lastState else {
            return // 下载已结束并进入播放态，无下载文案需要校验
        }

        let text = provider.localizedStateText(for: lastState)
        XCTAssertTrue(
            text.contains("\(Int(progress * 100))%"),
            "状态文案「\(text)」与进度 \(progress) 不一致，Hero 会显示分裂的两个百分比"
        )
    }

    /// Hero 底部小字的下载标签必须是不带百分比的纯文案。
    ///
    /// Hero 圆环中心已单独显示百分比（如 14%），底部小字再带百分比就会出现
    /// 「正在下载 14%」这样的重复信息。
    func testDownloadingLabelIsPlainTextWithoutPercentage() {
        let man = MagicPlayMan()
        let provider = PlaybackProvider(playback: man)

        let label = provider.localizedDownloadingLabel()
        XCTAssertFalse(label.isEmpty, "下载标签不应为空")
        XCTAssertFalse(
            label.contains("%"),
            "下载标签「\(label)」不应带百分比：Hero 圆环中心已单独显示百分比"
        )
        XCTAssertEqual(
            label,
            man.localization.downloading,
            "下载标签应取引擎本地化里的「正在下载」，而不是带百分比的状态文案"
        )
    }

    // MARK: - Helpers

    private static func makeTemporaryAudioFile() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlaybackDownloadProgressProviderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("track.mp3")
        try Data(repeating: 1, count: 1024).write(to: file)
        return file
    }
}
