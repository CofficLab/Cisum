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

    func testPlayerProgressBarIsPresent() {
        XCTAssertTrue(element(identifier: "cisum.player.progress").waitForExistence(timeout: 10), "播放进度条未出现")
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
        let settingsButton = element(identifier: "cisum.settings.button")
        XCTAssertTrue(settingsButton.exists, "顶部工具栏设置按钮未出现，无法计算播放器控制区顶部留白")
        XCTAssertLessThan(controls.frame.minY - settingsButton.frame.maxY, 200, "空仓库时工具栏与播放器之间仍有过大留白：工具栏=\(settingsButton.frame)，播放器=\(controls.frame)")
        let addButton = element(anyLabelOf: ["Add", "添加"])
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "音乐仓库添加入口不应随播放器收起而消失")
        XCTAssertGreaterThan(addButton.frame.minY, controls.frame.minY, "添加动作应处于下方仓库区域，而不是顶部播放器区域")
        #else
        throw XCTSkip("macOS 主窗口高度布局回归仅在 macOS UI 测试中覆盖")
        #endif
    }
}
