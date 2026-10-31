import XCTest

final class CisumPlayerUITests: CisumUITestBase {
    func testPlayerControlAreaIsPresent() {
        XCTAssertTrue(element(identifier: "cisum.player.controls").waitForExistence(timeout: 10), "播放器控制区未出现")
    }

    func testPlayerControlButtonsArePresent() {
        for label in ["More", "Previous", "Next", "Playback mode"] {
            XCTAssertTrue(
                app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch.exists,
                "缺少播放控制按钮：\(label)"
            )
        }
        let playPause = element(anyLabelOf: ["Play", "Pause"])
        XCTAssertTrue(playPause.exists, "缺少播放/暂停按钮")
    }

    /// 播放进度条必须出现。
    ///
    /// 注意：仓库**为空**时控制区会切换到「空仓库引导」布局，播放进度条
    /// 按设计让位给引导（见 `ControlView.showsProgressSection`）。因此本用例
    /// 必须先注入种子音频让仓库非空，否则断言的是另一种布局。
    func testPlayerProgressBarIsPresent() {
        // 空仓库时控制区切到「空仓库引导」布局，进度条按设计让位给引导。
        // 因此本用例另起一个注入种子音频的 App 实例，确保仓库非空。
        let seeded = makeAppWithSeededAudio()
        app.terminate()
        seeded.launch()
        XCTAssertTrue(
            seeded.descendants(matching: .any)
                .matching(identifier: "cisum.kernel.ready")
                .firstMatch.waitForExistence(timeout: 20),
            "注入种子音频的实例未在 20s 内完成主界面组装"
        )

        XCTAssertTrue(
            seeded.descendants(matching: .any)
                .matching(identifier: "cisum.player.progress")
                .firstMatch.waitForExistence(timeout: 10),
            "播放进度条未出现（仓库非空时应显示）"
        )
    }

    /// 进度条用例需要**非空**仓库（空仓库时控制区切到引导布局，
    /// 进度条按设计让位），因此单独起一个注入种子音频的 App 实例。
    private func makeAppWithSeededAudio() -> XCUIApplication {
        let instance = XCUIApplication()
        instance.launchArguments = additionalLaunchArguments + [
            "--cisum-ui-testing-seed-audio", "Cisum-UI-Player-Progress-Test-Tone.wav",
        ]
        return instance
    }

    func testPlayerCollapsesWhenThereIsNoCurrentTrack() throws {
        #if os(macOS)
        try ensureMusicScene()
        let controls = element(identifier: "cisum.player.controls")
        XCTAssertTrue(controls.waitForExistence(timeout: 10), "播放器控制区未出现")
        XCTAssertFalse(element(identifier: "cisum.player.title").exists, "无当前曲目时不应保留空标题区域")
        XCTAssertLessThan(controls.frame.height, 200, "无当前曲目时播放器应收起，为仓库腾出空间")
        for label in ["More", "Previous", "Play", "Next", "Playback mode"] {
            let button = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
            XCTAssertTrue(button.exists, "紧凑播放器缺少按钮：\(label)")
            XCTAssertGreaterThanOrEqual(button.frame.width, 44, "紧凑播放器按钮宽度低于 44pt：\(label)，frame=\(button.frame)")
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, "紧凑播放器按钮高度低于 44pt：\(label)，frame=\(button.frame)")
        }

        let repository = element(identifier: "cisum.scene.music")
        XCTAssertTrue(repository.exists, "播放器收起后音乐仓库仍应可见")
        XCTAssertFalse(element(identifier: "cisum.audio-library.count").exists, "确认仓库为空时不应显示列表计数栏")
        // 工具栏必须仍在（说明收起的是播放器，而不是把整个界面清空）。
        //
        // 注：工具栏与播放器之间的空档由「空仓库引导」占据
        // （`PluginRepositoryGuide`）——仓库为空时引导占顶部、控件沉底，
        // 这是该插件的设计目的，因此这里不再断言「不该有空档」。
        let settingsButton = element(identifier: "cisum.settings.button")
        XCTAssertTrue(settingsButton.exists, "顶部工具栏设置按钮未出现，无法确认界面未整体清空")
        let addButton = element(anyLabelOf: ["Add", "添加"])
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "音乐仓库添加入口不应随播放器收起而消失")
        XCTAssertGreaterThan(addButton.frame.minY, controls.frame.minY, "添加动作应处于下方仓库区域，而不是顶部播放器区域")
        #else
        throw XCTSkip("macOS 主窗口高度布局回归仅在 macOS UI 测试中覆盖")
        #endif
    }
}
