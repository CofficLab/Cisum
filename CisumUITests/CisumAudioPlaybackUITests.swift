import Foundation
import XCTest

/// 使用仓库内置的 60 秒 WAV 样本，覆盖“本地文件 -> 音乐仓库索引 -> 用户选择 -> 播放器状态”链路。
final class CisumAudioPlaybackUITests: CisumUITestBase {
    private let fixtureName = "Cisum-Playback-Test-Tone"
    private var fixtureURL: URL?

    override var additionalLaunchArguments: [String] {
        #if os(macOS)
        ["-StorageLocation", "local", "-UI.ShowDB", "YES"]
        #else
        []
        #endif
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

    func testSelectingBundledAudioStartsPlaybackAndCanPause() throws {
        #if os(macOS)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        if version.majorVersion >= 27 {
            throw XCTSkip("macOS 27 的系统文件选择器无法稳定完成跨进程 UI 自动化导入")
        }
        try ensureMusicScene()

        let stalePlaybackErrorDetails = app.staticTexts["错误详情"]
        if stalePlaybackErrorDetails.exists {
            let stalePlaybackErrorCloseButton = app.buttons["关闭"]
            XCTAssertTrue(stalePlaybackErrorCloseButton.waitForExistence(timeout: 3), "旧播放错误没有关闭入口")
            stalePlaybackErrorCloseButton.click()
            XCTAssertTrue(stalePlaybackErrorDetails.waitForNonExistence(timeout: 3), "旧播放错误面板没有关闭")
        }
        deleteImportedFixtureIfPresent(fixtureName: fixtureName)

        let importButton = element(anyLabelOf: ["Add", "添加"])
        XCTAssertTrue(importButton.waitForExistence(timeout: 10), "音乐仓库没有音频导入入口")
        importButton.click()

        let panelService = XCUIApplication(bundleIdentifier: "com.apple.appkit.xpc.openAndSavePanelService")
        let servicePanel = panelService.windows.firstMatch
        let appPanel = app.dialogs.firstMatch
        let appSheet = app.sheets.firstMatch
        let servicePanelAppeared = servicePanel.waitForExistence(timeout: 5)
        let panelAppeared = servicePanelAppeared
            || appPanel.waitForExistence(timeout: 1)
            || appSheet.waitForExistence(timeout: 1)
        XCTAssertTrue(panelAppeared, "点击导入后系统文件选择器没有出现。App UI：\(app.debugDescription)")
        let pickerApp: XCUIApplication = servicePanelAppeared ? panelService : app

        pickerApp.typeKey("g", modifierFlags: [.command, .shift])
        let goToFolderField = pickerApp.textFields["PathTextField"]
        XCTAssertTrue(goToFolderField.waitForExistence(timeout: 5), "文件选择器没有显示路径输入框")
        goToFolderField.click()
        goToFolderField.typeKey("a", modifierFlags: .command)
        let fixtureFolderPath = try XCTUnwrap(fixtureURL).deletingLastPathComponent().path
        goToFolderField.typeText(fixtureFolderPath)
        XCTAssertEqual(goToFolderField.value as? String, fixtureFolderPath, "文件选择器未收到测试资源目录路径")
        pickerApp.typeKey(.return, modifierFlags: [])
        pickerApp.typeKey(.return, modifierFlags: [])

        let fixtureRow = element(containing: String(fixtureName.prefix(18)))
        XCTAssertTrue(fixtureRow.waitForExistence(timeout: 10), "文件选择器未定位到测试音频")
        fixtureRow.doubleClick()

        XCTAssertTrue(
            pickerApp.windows.firstMatch.waitForNonExistence(timeout: 15)
                || app.dialogs.firstMatch.waitForNonExistence(timeout: 1),
            "文件选择器关闭前未完成测试音频导入"
        )

        let track = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", fixtureName)).firstMatch
        XCTAssertTrue(track.waitForExistence(timeout: 30), "测试音频未出现在音乐仓库：\(fixtureName)")
        track.click()

        let pauseButton = app.buttons.matching(NSPredicate(format: "label == %@", "Pause")).firstMatch
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 15), "选择音频后播放器没有进入播放态")

        let playerTitle = element(identifier: "cisum.player.title")
        XCTAssertTrue(playerTitle.waitForExistence(timeout: 10), "播放时主播放器曲目标题没有显示")
        XCTAssertGreaterThanOrEqual(element(identifier: "cisum.player.controls").frame.height, 240, "有当前曲目时播放器标题区域应恢复")
        let titleMatchesCurrentTrack = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@ OR value == %@", fixtureName, fixtureName),
            object: playerTitle
        )
        XCTAssertEqual(XCTWaiter.wait(for: [titleMatchesCurrentTrack], timeout: 10), .completed, "主播放器标题没有反映当前播放曲目")
        XCTAssertEqual(playerTitle.value as? String ?? playerTitle.label, fixtureName, "主播放器标题没有反映当前播放曲目")

        let progress = element(identifier: "cisum.player.progress")
        XCTAssertTrue(progress.waitForExistence(timeout: 10), "播放时主播放器进度条没有显示")
        let progressAdvances = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value > 0"), object: progress)
        XCTAssertEqual(XCTWaiter.wait(for: [progressAdvances], timeout: 10), .completed, "播放进度没有随音频推进")

        pauseButton.click()
        let playButton = app.buttons.matching(NSPredicate(format: "label == %@", "Play")).firstMatch
        XCTAssertTrue(playButton.waitForExistence(timeout: 10), "点击暂停后播放器没有回到暂停态")
        playButton.click()
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 10), "恢复播放后播放器没有回到播放态")
        pauseButton.click()
        XCTAssertTrue(playButton.waitForExistence(timeout: 10), "第二次暂停后播放器状态不正确")

        deleteImportedFixtureIfPresent(fixtureName: fixtureName)
        XCTAssertTrue(track.waitForNonExistence(timeout: 15), "测试音频未从音乐仓库清理")
        #else
        throw XCTSkip("音频仓库文件夹播放回归当前仅在 macOS UI 测试中覆盖")
        #endif
    }

    /// 切歌后进度归零：播放歌曲1 → 进度推进 → 切换到歌曲2 → 进度必须归零。
    /// 注意：此测试依赖系统文件选择器自动化，macOS 27+ 可能跳过。
    func testSwitchingTracksResetsProgressToZero() throws {
        #if os(macOS)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        if version.majorVersion >= 27 {
            throw XCTSkip("macOS 27 的系统文件选择器无法稳定完成跨进程 UI 自动化导入")
        }
        try ensureMusicScene()

        // 清理旧的导入
        deleteImportedFixtureIfPresent(fixtureName: fixtureName)
        deleteImportedFixtureIfPresent(fixtureName: fixtureName2)

        // 导入歌曲1
        importFixtureViaFilePicker(fixtureURL: try XCTUnwrap(fixtureURL))
        let track1 = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", fixtureName)).firstMatch
        XCTAssertTrue(track1.waitForExistence(timeout: 30), "歌曲1未出现在音乐仓库")

        // 导入歌曲2（使用同一文件的不同副本）
        let fixtureURL2 = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(fixtureName2).wav")
        importFixtureViaFilePicker(fixtureURL: fixtureURL2)
        let track2 = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", fixtureName2)).firstMatch
        XCTAssertTrue(track2.waitForExistence(timeout: 30), "歌曲2未出现在音乐仓库")

        // 播放歌曲1
        track1.click()
        let pauseButton = app.buttons.matching(NSPredicate(format: "label == %@", "Pause")).firstMatch
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 15), "歌曲1未开始播放")

        // 等待进度推进（> 0）
        let progress = element(identifier: "cisum.player.progress")
        XCTAssertTrue(progress.waitForExistence(timeout: 10), "进度条未出现")
        let progressAdvances = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value > 0.05"), object: progress)
        XCTAssertEqual(XCTWaiter.wait(for: [progressAdvances], timeout: 10), .completed, "歌曲1进度未推进")

        // 切换到歌曲2
        track2.click()
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 15), "歌曲2未开始播放")

        // 进度必须归零（允许小延迟，但应在 2 秒内归零）
        let progressResets = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value < 0.01"), object: progress)
        XCTAssertEqual(XCTWaiter.wait(for: [progressResets], timeout: 5), .completed, "切歌后进度未归零，实际值: \(progress.value ?? "nil")")

        // 等待 1 秒，确保不会死灰复燃
        Thread.sleep(forTimeInterval: 1.0)
        let currentValue = (progress.value as? Double) ?? 0
        XCTAssertLessThan(currentValue, 0.01, "切歌后进度不得死灰复燃，实际值: \(currentValue)")

        // 清理
        deleteImportedFixtureIfPresent(fixtureName: fixtureName)
        deleteImportedFixtureIfPresent(fixtureName: fixtureName2)
        #else
        throw XCTSkip("切歌归零回归当前仅在 macOS UI 测试中覆盖")
        #endif
    }

    private let fixtureName2 = "Cisum-Playback-Test-Tone-2"
}
