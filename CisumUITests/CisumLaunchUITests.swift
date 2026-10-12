import XCTest

final class CisumLaunchUITests: CisumUITestBase {
    func testLaunchReachesRootWithoutStartupError() {
        #if os(macOS)
        XCTAssertTrue(app.windows["Cisum"].waitForExistence(timeout: 10))
        #endif
    }

    func testLaunchShowsAContentScene() {
        let musicScene = element(identifier: "cisum.scene.music")
        let audiobooksScene = element(identifier: "cisum.scene.audiobooks")
        let hasContentScene = musicScene.waitForExistence(timeout: 10)
            || audiobooksScene.waitForExistence(timeout: 10)

        XCTAssertTrue(
            hasContentScene,
            "Cisum reached kernel-ready but launched without a visible music-library or audiobook scene; this matches the collapsed-player-only screen."
        )
    }

    func testSettingsCommandOpensDedicatedWindow() throws {
        #if os(macOS)
        openSettingsWindowViaMenu()
        XCTAssertTrue(element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15), "Settings… 命令未打开设置窗口")
        XCTAssertFalse(element(identifier: "cisum.kernel.startup-error").exists)
        #else
        throw XCTSkip("设置菜单命令仅 macOS 支持")
        #endif
    }

    func testToolbarSettingsButtonOpensSettingsWindow() throws {
        #if os(macOS)
        XCTAssertTrue(app.windows["Cisum"].waitForExistence(timeout: 10))
        let toolbarButton = element(identifier: "cisum.settings.button")
        XCTAssertTrue(toolbarButton.waitForExistence(timeout: 10), "工具栏设置按钮不可用")
        toolbarButton.click()

        XCTAssertTrue(element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15), "工具栏设置按钮未打开设置窗口")
        XCTAssertFalse(element(identifier: "cisum.kernel.startup-error").exists)
        #else
        throw XCTSkip("工具栏设置按钮仅 macOS 支持")
        #endif
    }

    func testToolbarSettingsRoundTripPreservesMainWindowLayout() throws {
        #if os(macOS)
        let window = app.windows["Cisum"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        let toolbarButton = element(identifier: "cisum.settings.button")
        XCTAssertTrue(toolbarButton.waitForExistence(timeout: 10), "工具栏设置按钮不可用")
        toolbarButton.click()
        XCTAssertTrue(element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15), "工具栏设置按钮未打开设置窗口")

        closeSettingsWindow()
        try ensureMusicScene()
        let controls = element(identifier: "cisum.player.controls")
        XCTAssertTrue(controls.waitForExistence(timeout: 10), "播放器控制区未恢复")
        for label in ["More", "Previous", "Play", "Next", "Playback mode"] {
            let button = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
            assertElementFitsWindow(button, window: window, description: "播放器按钮「\(label)」")
        }

        let musicScene = element(identifier: "cisum.scene.music")
        assertElementFitsWindow(musicScene, window: window, description: "音乐仓库场景")
        #else
        throw XCTSkip("设置窗口回归测试仅 macOS 支持")
        #endif
    }
}
