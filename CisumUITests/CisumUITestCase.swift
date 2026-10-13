import Foundation
import XCTest

/// 所有 Cisum UI 测试的公共基类。
///
/// - 每个用例独立启动 App 并等待内核就绪（`cisum.kernel.ready`）。
/// - 元素查找优先使用产品公开的 accessibility identifier；对本地化文本
///   （中 / 英文 Scheme）提供双语言候选匹配。
/// - 设置入口测试仅适用于 macOS，其他平台显式跳过而非失败。
class CisumUITestBase: XCTestCase {
    var app: XCUIApplication!
    var additionalLaunchArguments: [String] {
        ["--cisum-ui-testing", "--cisum-ui-testing-storage-local"]
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += additionalLaunchArguments
        app.launch()
        waitForKernelReady()
    }

    func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func element(anyLabelOf labels: [String]) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label IN %@ OR value IN %@", labels, labels))
            .firstMatch
    }

    func element(labelBeginsWith prefixes: [String]) -> XCUIElement {
        let predicates = prefixes.map {
            NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", $0, $0)
        }
        return app.descendants(matching: .any)
            .matching(NSCompoundPredicate(orPredicateWithSubpredicates: predicates))
            .firstMatch
    }

    func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text))
            .firstMatch
    }

    func element(containingAny texts: [String]) -> XCUIElement {
        let predicates = texts.map {
            NSPredicate(format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@", $0, $0)
        }
        return app.descendants(matching: .any)
            .matching(NSCompoundPredicate(orPredicateWithSubpredicates: predicates))
            .firstMatch
    }

    func waitForKernelReady(timeout: TimeInterval = 20) {
        XCTAssertTrue(
            element(identifier: "cisum.kernel.ready").waitForExistence(timeout: timeout),
            "Cisum 未在 \(timeout)s 内完成主界面组装"
        )
        XCTAssertFalse(
            element(identifier: "cisum.kernel.startup-error").exists,
            "Cisum 显示了启动错误屏"
        )
    }

    func switchScene(to labels: [String]) {
        #if os(macOS)
        let sceneID = labels.contains(where: { ["Music Library", "音乐仓库"].contains($0) })
            ? "music"
            : "audiobooks"
        let targetScene = element(identifier: "cisum.scene.\(sceneID)")
        if targetScene.waitForExistence(timeout: 1) { return }

        let switcher = element(identifier: "cisum.scene.switcher")
        XCTAssertTrue(switcher.waitForExistence(timeout: 10), "工具栏找不到场景切换器")
        switcher.click()

        let segment = element(identifier: "cisum.scene.option.\(sceneID)")
        XCTAssertTrue(segment.waitForExistence(timeout: 5), "场景选择器中找不到目标场景：\(labels)")
        segment.click()

        let enterButton = element(identifier: "cisum.scene.enter.\(sceneID)")
        if enterButton.waitForExistence(timeout: 5) {
            enterButton.click()
            XCTAssertTrue(targetScene.waitForExistence(timeout: 10), "点击「进入场景」后目标场景未出现：\(sceneID)")
        } else {
            XCTAssertTrue(targetScene.waitForExistence(timeout: 5), "找不到「进入场景」按钮，且目标场景未直接切换")
        }
        #endif
    }

    func ensureMusicScene() throws {
        #if os(macOS)
        switchScene(to: ["Music Library", "音乐仓库"])
        #else
        if !element(identifier: "cisum.scene.music").exists {
            throw XCTSkip("iOS 上无法通过 UI 切换场景，且当前不在音乐场景")
        }
        #endif
    }

    func ensureAudiobooksScene() throws {
        #if os(macOS)
        switchScene(to: ["Audiobooks", "有声书"])
        #else
        if !element(identifier: "cisum.scene.audiobooks").exists {
            throw XCTSkip("iOS 上无法通过 UI 切换场景，且当前不在有声书场景")
        }
        #endif
    }

    #if os(macOS)
    /// 通过系统文件选择器导入测试音频。
    ///
    /// 音乐仓库没有公开的自动化导入入口，只能驱动真实选择器。
    /// 注意：macOS 27+ 的跨进程选择器自动化不稳定，调用方应先按版本跳过。
    func importFixtureViaFilePicker(fixtureURL: URL) {
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
        let fixtureFolderPath = fixtureURL.deletingLastPathComponent().path
        goToFolderField.typeText(fixtureFolderPath)
        pickerApp.typeKey(.return, modifierFlags: [])
        pickerApp.typeKey(.return, modifierFlags: [])

        let name = fixtureURL.deletingPathExtension().lastPathComponent
        let fixtureRow = element(containing: String(name.prefix(18)))
        XCTAssertTrue(fixtureRow.waitForExistence(timeout: 10), "文件选择器未定位到测试音频: \(name)")
        fixtureRow.doubleClick()

        XCTAssertTrue(
            pickerApp.windows.firstMatch.waitForNonExistence(timeout: 15)
                || app.dialogs.firstMatch.waitForNonExistence(timeout: 1),
            "文件选择器关闭前未完成测试音频导入"
        )
    }

    /// 删除此前导入的测试音频，保持仓库干净。
    func deleteImportedFixtureIfPresent(fixtureName: String) {
        let track = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", fixtureName)).firstMatch
        guard track.exists else { return }

        track.rightClick()
        let deleteMenuItem = app.menuItems.matching(identifier: "trash").firstMatch
        XCTAssertTrue(deleteMenuItem.waitForExistence(timeout: 5), "曲目上下文菜单中没有删除命令")
        deleteMenuItem.click()

        let confirmDelete = app.buttons.matching(identifier: "Delete").firstMatch
            .exists
            ? app.buttons.matching(identifier: "Delete").firstMatch
            : app.buttons.matching(identifier: "删除").firstMatch
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), "删除确认没有出现")
        confirmDelete.click()
        XCTAssertTrue(track.waitForNonExistence(timeout: 15), "测试音频未从音乐仓库清理: \(fixtureName)")
    }

    /// macOS 27+ 的系统文件选择器无法稳定完成跨进程 UI 自动化导入。
    func skipIfFilePickerAutomationUnavailable() throws {
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 {
            throw XCTSkip("macOS 27 的系统文件选择器无法稳定完成跨进程 UI 自动化导入")
        }
    }
    #endif

    #if os(macOS)
    func assertElementFitsWindow(
        _ element: XCUIElement,
        window: XCUIElement,
        description: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.exists, "\(description)未渲染", file: file, line: line)
        XCTAssertGreaterThan(element.frame.width, 0, "\(description)没有有效宽度", file: file, line: line)
        XCTAssertGreaterThan(element.frame.height, 0, "\(description)没有有效高度", file: file, line: line)
        XCTAssertTrue(
            window.frame.insetBy(dx: -2, dy: -2).contains(element.frame),
            "\(description)超出主窗口：id=\(element.identifier), label=\(element.label), value=\(element.value ?? "nil"), element=\(element.frame), window=\(window.frame)",
            file: file,
            line: line
        )
    }

    func text(containing fragments: [String]) -> XCUIElement {
        let predicates = fragments.map {
            NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", $0, $0)
        }
        return app.staticTexts.matching(NSCompoundPredicate(orPredicateWithSubpredicates: predicates)).firstMatch
    }
    #endif

    func openSettingsWindowViaMenu() {
        #if os(macOS)
        XCTAssertTrue(app.windows["Cisum"].waitForExistence(timeout: 10))

        let appMenu = app.menuBars.menuBarItems["Cisum"]
        XCTAssertTrue(appMenu.waitForExistence(timeout: 5), "Cisum 应用菜单不可用")
        appMenu.click()

        let settingsCommand = app.menuItems["Settings…"]
        XCTAssertTrue(settingsCommand.waitForExistence(timeout: 5), "Settings… 命令不可用")
        settingsCommand.click()
        #endif
    }

    func closeSettingsWindow() {
        #if os(macOS)
        let settingsWindow = app.windows.matching(identifier: "cisum.settings").firstMatch
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 10), "设置窗口未出现，无法关闭")

        let closeButtonCandidates = [
            settingsWindow.buttons.matching(identifier: "_XCUI:CloseWindow").firstMatch,
            settingsWindow.buttons.matching(identifier: "AXCloseButton").firstMatch,
            settingsWindow.buttons["Close"],
            settingsWindow.buttons["关闭"],
        ]
        guard let closeButton = closeButtonCandidates.first(where: { $0.waitForExistence(timeout: 2) }) else {
            XCTFail("设置窗口没有可用的关闭按钮：\n\(settingsWindow.debugDescription)")
            return
        }

        closeButton.click()
        XCTAssertTrue(settingsWindow.waitForNonExistence(timeout: 10), "设置窗口关闭后仍然存在")
        XCTAssertTrue(app.windows["Cisum"].waitForExistence(timeout: 10), "关闭设置窗口后主窗口没有恢复")
        #endif
    }
}
