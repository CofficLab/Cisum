import Foundation
import XCTest

/// 顶部工具栏「Show in Finder」按钮：无当前曲目时隐藏、有曲目时显示、工具栏可用。
final class CisumOpenButtonUITests: CisumUITestBase {
    func testShowInFinderButtonIsHiddenWhenNoTrackIsPlaying() throws {
        #if os(macOS)
        XCTAssertTrue(app.windows["Cisum"].waitForExistence(timeout: 10), "主窗口未出现")

        let showInFinderButton = app.buttons.matching(
            NSPredicate(format: "label == %@", "Show in Finder")
        ).firstMatch
        XCTAssertFalse(
            showInFinderButton.exists,
            "无当前曲目时「Show in Finder」工具栏按钮不应可见"
        )
        #else
        throw XCTSkip("「Show in Finder」工具栏按钮仅 macOS 支持")
        #endif
    }

    func testToolbarRemainsFunctionalWithoutOpenButton() throws {
        #if os(macOS)
        let settingsButton = element(identifier: "cisum.settings.button")
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10), "工具栏设置按钮不可用，工具栏可能未正常加载")

        let sceneSwitcher = element(identifier: "cisum.scene.switcher")
        XCTAssertTrue(sceneSwitcher.waitForExistence(timeout: 10), "场景切换器不可用，工具栏可能未正常加载")
        #else
        throw XCTSkip("工具栏回归仅 macOS 支持")
        #endif
    }

    func testShowInFinderButtonAppearsWhenPlayingLocalTrack() throws {
        #if os(macOS)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        if version.majorVersion >= 27 {
            throw XCTSkip("macOS 27 的系统文件选择器无法稳定完成跨进程 UI 自动化导入")
        }

        // 导入测试音频
        let fixtureName = "Cisum-Playback-Test-Tone"
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(fixtureName).wav")
        XCTAssertTrue(FileManager.default.isReadableFile(atPath: fixtureURL.path), "测试音频样本不可读")

        try ensureMusicScene()

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
        XCTAssertTrue(panelAppeared, "点击导入后系统文件选择器没有出现")
        let pickerApp: XCUIApplication = servicePanelAppeared ? panelService : app

        pickerApp.typeKey("g", modifierFlags: [.command, .shift])
        let goToFolderField = pickerApp.textFields["PathTextField"]
        XCTAssertTrue(goToFolderField.waitForExistence(timeout: 5), "文件选择器没有显示路径输入框")
        goToFolderField.click()
        goToFolderField.typeKey("a", modifierFlags: .command)
        goToFolderField.typeText(fixtureURL.deletingLastPathComponent().path)
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

        // 播放曲目
        let track = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", fixtureName)).firstMatch
        XCTAssertTrue(track.waitForExistence(timeout: 30), "测试音频未出现在音乐仓库")
        track.click()

        // 确认播放已开始
        let pauseButton = app.buttons.matching(NSPredicate(format: "label == %@", "Pause")).firstMatch
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 15), "选择音频后播放器没有进入播放态")

        // 验证 Finder 按钮出现
        let showInFinderButton = app.buttons.matching(
            NSPredicate(format: "label == %@", "Show in Finder")
        ).firstMatch
        XCTAssertTrue(
            showInFinderButton.waitForExistence(timeout: 10),
            "播放本地曲目后「Show in Finder」工具栏按钮应当可见"
        )

        // 清理
        track.rightClick()
        let deleteMenuItem = app.menuItems.matching(identifier: "trash").firstMatch
        if deleteMenuItem.waitForExistence(timeout: 3) {
            deleteMenuItem.click()
            let confirmDelete = app.buttons.matching(NSPredicate(format: "label IN %@", ["Delete", "删除"])).firstMatch
            if confirmDelete.waitForExistence(timeout: 3) {
                confirmDelete.click()
                track.waitForNonExistence(timeout: 10)
            }
        }
        #else
        throw XCTSkip("「Show in Finder」工具栏按钮回归仅 macOS 支持")
        #endif
    }
}
