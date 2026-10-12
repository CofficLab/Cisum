import XCTest

/// 场景切换器：工具栏入口、场景选择器弹出、场景切换后内容区跟随变化。
final class CisumSceneSwitcherUITests: CisumUITestBase {
    func testSceneSwitcherOpensScenePicker() throws {
        #if os(macOS)
        let switcher = element(identifier: "cisum.scene.switcher")
        XCTAssertTrue(switcher.waitForExistence(timeout: 10), "工具栏找不到场景切换器")
        switcher.click()
        XCTAssertTrue(element(anyLabelOf: ["Music Library", "音乐仓库", "Audiobooks", "有声书"]).waitForExistence(timeout: 5), "场景选择器未弹出")
        #else
        throw XCTSkip("场景切换器仅 macOS 支持")
        #endif
    }

    func testSceneSwitcherSwitchesBetweenScenes() throws {
        #if os(macOS)
        try ensureAudiobooksScene()
        XCTAssertTrue(element(identifier: "cisum.scene.audiobooks").waitForExistence(timeout: 10), "切换到有声书场景后内容区未更新")
        try ensureMusicScene()
        XCTAssertTrue(element(identifier: "cisum.scene.music").waitForExistence(timeout: 10), "切回音乐场景后内容区未更新")
        #else
        throw XCTSkip("场景切换器仅 macOS 支持")
        #endif
    }
}
