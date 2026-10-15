import Foundation
import XCTest

/// 播放链路回归：仓库条目 → 用户选择 → 播放器状态 → 进度推进 / 切歌归零。
///
/// 跨平台策略（重要）：
/// - **macOS**：保留原有的系统文件选择器导入路径，验证真实用户路径
///   （`importFixtureViaFilePicker` 导入 `Fixtures/` 下的真实 WAV）。
/// - **iOS**：模拟器没有可驱动的系统文件选择器，改为依赖 App 内建的
///   `--cisum-ui-testing-seed-audio` 注入（运行时合成真实 PCM WAV 写入沙盒，
///   见 `UITestAudioSeedTone`）+ `--cisum-ui-testing-playback-file` 启动恢复播放。
///   两种路径断言同一组播放器行为，覆盖的产品代码路径是相同的。
///
/// 平台差异只在「音频如何进入仓库」这一步，其后的全部断言跨平台共用。
final class CisumAudioPlaybackUITests: CisumUITestBase {
    /// macOS 真实导入用的 fixture 名。
    private let fixtureName = "Cisum-Playback-Test-Tone"
    private let fixtureName2 = "Cisum-Playback-Test-Tone-2"

    /// iOS 注入用的种子音频名（无需真实文件，App 启动时合成）。
    private let seededAudioName = "Cisum-UI-Playback-Seeded-Tone.wav"
    private let seededAudioName2 = "Cisum-UI-Playback-Seeded-Tone-2.wav"

    private var fixtureURL: URL?

    override var additionalLaunchArguments: [String] {
        var arguments = super.additionalLaunchArguments
        #if os(macOS)
        arguments += ["-StorageLocation", "local", "-UI.ShowDB", "YES"]
        #else
        // iOS：注入两份种子音频，让「切歌」用例有两个可切换条目。
        // 逗号分隔的多名称由 AudioDBDataPlugin 解析；显式时长保证进度断言有观察窗口。
        arguments += [
            "--cisum-ui-testing-seed-audio", "\(seededAudioName),\(seededAudioName2)",
            "--cisum-ui-testing-seed-duration", "60",
        ]
        #endif
        return arguments
    }

    override func setUpWithError() throws {
        #if os(macOS)
        fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(fixtureName).wav")
        XCTAssertTrue(FileManager.default.isReadableFile(atPath: try XCTUnwrap(fixtureURL).path), "项目中的测试音频样本不可读")
        #endif
        try super.setUpWithError()
    }

    override func tearDownWithError() throws {
        #if os(macOS)
        if app.state == .runningForeground || app.state == .runningBackground {
            app.terminate()
        }
        #endif
        try super.tearDownWithError()
    }

    // MARK: - 跨平台辅助

    /// 当前平台上「播放 / 暂停 / 进度推进」用例所使用的主曲目名。
    ///
    /// macOS 走真实 fixture 导入，iOS 走启动期合成注入，两者文件名不同，
    /// 但其后的播放器断言完全共用。
    private var primaryTrackName: String {
        #if os(macOS)
        fixtureName
        #else
        seededAudioName
        #endif
    }

    /// 平台相关的准备：macOS 需导入 fixture，iOS 依赖启动注入。
    private func preparePlayableTrack() throws {
        #if os(macOS)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        if version.majorVersion >= 27 {
            throw XCTSkip("macOS 27 的系统文件选择器无法稳定完成跨进程 UI 自动化导入")
        }
        try ensureMusicScene()
        deleteImportedFixtureIfPresent(fixtureName: fixtureName)
        importFixtureViaFilePicker(fixtureURL: try XCTUnwrap(fixtureURL))
        #else
        try ensureMusicScene()
        #endif
    }

    /// 清理平台相关残留。
    private func cleanupPlayableTrack() {
        #if os(macOS)
        deleteImportedFixtureIfPresent(fixtureName: fixtureName)
        #endif
    }

    /// 激活某个条目并等待进入播放态，返回暂停按钮（用于后续切换断言）。
    private func startPlayback(trackName: String) throws -> XCUIElement {
        let track = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", trackName)).firstMatch
        XCTAssertTrue(track.waitForExistence(timeout: 30), "测试音频未出现在音乐仓库：\(trackName)")

        #if os(macOS)
        track.click()
        #else
        track.tap()
        #endif

        let pauseButton = app.buttons.matching(NSPredicate(format: "label == %@", "Pause")).firstMatch
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 15), "选择「\(trackName)」后播放器没有进入播放态")
        return pauseButton
    }

    /// 等待进度条推进到指定阈值以上。
    private func waitForProgress(above threshold: Double, timeout: TimeInterval, label: String) {
        let progress = element(identifier: "cisum.player.progress")
        XCTAssertTrue(progress.waitForExistence(timeout: 10), "进度条未出现")
        let advanced = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value > %f", threshold),
            object: progress
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [advanced], timeout: timeout), .completed,
            "\(label)：进度未推进到 \(threshold) 以上，实际 \(progress.value ?? "nil")"
        )
    }

    // MARK: - 用例

    /// 选择本地音频 → 进入播放态 → 进度推进 → 暂停 / 恢复。
    func testSelectingBundledAudioStartsPlaybackAndCanPause() throws {
        try preparePlayableTrack()

        let trackName = primaryTrackName
        let pauseButton = try startPlayback(trackName: trackName)
        let playButton = app.buttons.matching(NSPredicate(format: "label == %@", "Play")).firstMatch

        // 播放器标题区域：有当前曲目时应展开
        let playerTitle = element(identifier: "cisum.player.title")
        XCTAssertTrue(playerTitle.waitForExistence(timeout: 10), "播放时主播放器曲目标题没有显示")
        // `value` 是 Any?，需先转成字符串再判断，避免对非标量类型调用 contains。
        let titleValue = playerTitle.value as? String
        let titleText = [playerTitle.label, titleValue]
            .compactMap { $0 }
            .joined(separator: " ")
        XCTAssertTrue(
            titleText.contains(trackName),
            "主播放器标题没有反映当前播放曲目：label=\(playerTitle.label), value=\(titleValue ?? "nil")"
        )
        XCTAssertGreaterThanOrEqual(
            element(identifier: "cisum.player.controls").frame.height, 240,
            "有当前曲目时播放器标题区域应恢复"
        )

        // 进度必须随真实音频流推进（这正是 seed 需要合成真实 WAV 的原因）
        waitForProgress(above: 0, timeout: 10, label: "播放中")

        // 暂停 → 恢复 → 再暂停
        #if os(macOS)
        pauseButton.click()
        #else
        pauseButton.tap()
        #endif
        XCTAssertTrue(playButton.waitForExistence(timeout: 10), "点击暂停后播放器没有回到暂停态")

        #if os(macOS)
        playButton.click()
        #else
        playButton.tap()
        #endif
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 10), "恢复播放后播放器没有回到播放态")

        #if os(macOS)
        pauseButton.click()
        #else
        pauseButton.tap()
        #endif
        XCTAssertTrue(playButton.waitForExistence(timeout: 10), "第二次暂停后播放器状态不正确")

        cleanupPlayableTrack()
    }

    /// 切歌后进度归零：播放歌曲1 → 进度推进 → 切换到歌曲2 → 进度必须归零。
    func testSwitchingTracksResetsProgressToZero() throws {
        #if os(macOS)
        try preparePlayableTrack()
        let track1Name = fixtureName
        let track2Name = fixtureName2

        let fixtureURL2 = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(fixtureName2).wav")
        importFixtureViaFilePicker(fixtureURL: fixtureURL2)
        #else
        try ensureMusicScene()
        let track1Name = seededAudioName
        let track2Name = seededAudioName2
        #endif

        _ = try startPlayback(trackName: track1Name)
        waitForProgress(above: 0.05, timeout: 10, label: "歌曲1")

        // 切换到歌曲2
        let track2 = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", track2Name)).firstMatch
        XCTAssertTrue(track2.waitForExistence(timeout: 30), "歌曲2未出现在音乐仓库：\(track2Name)")
        #if os(macOS)
        track2.click()
        #else
        track2.tap()
        #endif

        let pauseButton = app.buttons.matching(NSPredicate(format: "label == %@", "Pause")).firstMatch
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 15), "歌曲2未开始播放")

        // 进度必须归零（允许小延迟，但应在 5s 内归零）
        let progress = element(identifier: "cisum.player.progress")
        let reset = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value < 0.01"), object: progress)
        XCTAssertEqual(
            XCTWaiter.wait(for: [reset], timeout: 5), .completed,
            "切歌后进度未归零，实际值: \(progress.value ?? "nil")"
        )

        // 等待 1 秒，确保不会死灰复燃
        Thread.sleep(forTimeInterval: 1.0)
        let currentValue = (progress.value as? Double) ?? 0
        XCTAssertLessThan(currentValue, 0.01, "切歌后进度不得死灰复燃，实际值: \(currentValue)")

        #if os(macOS)
        deleteImportedFixtureIfPresent(fixtureName: fixtureName)
        deleteImportedFixtureIfPresent(fixtureName: fixtureName2)
        #endif
    }
}
