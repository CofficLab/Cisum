//
//  CisumUITests.swift
//  CisumUITests
//
//  Created by Angel on 2026/9/26.
//

import XCTest

// MARK: - 公共基类

/// 所有 Cisum UI 测试的公共基类。
///
/// - 每个用例独立启动 App 并等待内核就绪（`cisum.kernel.ready`），
///   保证启动冒烟在所有用例上都被隐式覆盖。
/// - 元素查找优先使用产品公开的 accessibility identifier；对本地化文本
///   （中 / 英文 Scheme）提供双语言候选匹配，保持既有“中英文可复用”原则。
/// - 设置入口测试仅适用于 macOS（iOS 没有菜单栏与独立设置窗口），
///   其他平台显式跳过而非失败。
class CisumUITestBase: XCTestCase {
    var app: XCUIApplication!
    var additionalLaunchArguments: [String] { [] }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += additionalLaunchArguments
        app.launch()
        waitForKernelReady()
    }

    // MARK: - 元素查找

    /// 按 accessibility identifier 查找（最稳定，优先使用）。
    func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// 按多个候选 label（中英文）查找任意一个匹配元素。
    func element(anyLabelOf labels: [String]) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label IN %@ OR value IN %@", labels, labels))
            .firstMatch
    }

    /// 按 label 前缀查找（例如列表表头 “Total 86” / “共 86 首”）。
    func element(labelBeginsWith prefixes: [String]) -> XCUIElement {
        let predicates = prefixes.map {
            NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", $0, $0)
        }
        return app.descendants(matching: .any)
            .matching(NSCompoundPredicate(orPredicateWithSubpredicates: predicates))
            .firstMatch
    }

    /// 按 accessibility label 或 value 包含的文本片段查找，适用于 macOS
    /// 把同一状态视图的标题和说明合并为一个 value 的情况。
    func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text))
            .firstMatch
    }

    /// 等待内核就绪，且未进入启动错误屏。
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

    // MARK: - 跨场景辅助

    /// 通过工具栏场景切换器（popover）切换到目标场景。
    /// 仅 macOS 支持（工具栏 / popover 场景选择器为 macOS 专属）。
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

    /// 确保当前处于音乐场景；iOS 无场景切换器，仅在已处于音乐场景时继续。
    func ensureMusicScene() throws {
        #if os(macOS)
        switchScene(to: ["Music Library", "音乐仓库"])
        #else
        if !element(identifier: "cisum.scene.music").exists {
            throw XCTSkip("iOS 上无法通过 UI 切换场景，且当前不在音乐场景")
        }
        #endif
    }

    /// 确保当前处于有声书场景。
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
    func assertElementFitsWindow(_ element: XCUIElement, window: XCUIElement, description: String, file: StaticString = #filePath, line: UInt = #line) {
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

    /// 通过菜单栏「Cisum → Settings…」打开设置窗口（macOS）。
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
}

// MARK: - 启动冒烟（覆盖 App 级回归）

/// 用户最先感知的 App 级回归：内核启动、设置入口可用性。
/// 启动状态断言在两个平台（macOS / iOS Simulator）上运行；
/// 设置入口测试仅适用 macOS，其他平台显式跳过。
final class CisumLaunchUITests: CisumUITestBase {
    func testLaunchReachesRootWithoutStartupError() {
        // 基类 setUp 已断言 cisum.kernel.ready 存在且无启动错误屏；
        // 此处补充主窗口可见性。
        #if os(macOS)
        XCTAssertTrue(app.windows["Cisum"].waitForExistence(timeout: 10))
        #endif
    }

    func testLaunchShowsAContentScene() {
        // Do not open the scene switcher or toggle content visibility here:
        // this checks the state users actually get immediately after launch.
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
        XCTAssertTrue(
            element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15),
            "Settings… 命令未打开设置窗口"
        )
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

        XCTAssertTrue(
            element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15),
            "工具栏设置按钮未打开设置窗口"
        )
        XCTAssertFalse(element(identifier: "cisum.kernel.startup-error").exists)
        #else
        throw XCTSkip("工具栏设置按钮仅 macOS 支持")
        #endif
    }
}

// MARK: - 播放器控制区（原型 02）

/// 播放器控制区：控制按钮组与进度条的呈现与状态反映。
/// 播放/暂停的真实状态切换依赖音频资产，此处只做 UI 呈现与状态反映断言。
final class CisumPlayerUITests: CisumUITestBase {
    func testPlayerControlAreaIsPresent() {
        XCTAssertTrue(
            element(identifier: "cisum.player.controls").waitForExistence(timeout: 10),
            "播放器控制区未出现"
        )
    }

    func testPlayerControlButtonsArePresent() {
        // 更多 / 上一曲 / 播放暂停 / 下一曲 / 播放模式，label 为产品固定值。
        for label in ["More", "Previous", "Next", "Playback mode"] {
            XCTAssertTrue(
                app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch.exists,
                "缺少播放控制按钮：\(label)"
            )
        }
        // 播放/暂停二选一必须存在（取决于当前播放状态）。
        let playPause = element(anyLabelOf: ["Play", "Pause"])
        XCTAssertTrue(playPause.exists, "缺少播放/暂停按钮")
    }

    func testPlayerProgressBarIsPresent() {
        XCTAssertTrue(
            element(identifier: "cisum.player.progress").waitForExistence(timeout: 10),
            "播放进度条未出现"
        )
    }

}

// MARK: - 音频真实播放链路

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
        try ensureMusicScene()

        // 上一次若在断言中途失败，先清理遗留样本，让测试可重复运行。
        let stalePlaybackErrorDetails = app.staticTexts["错误详情"]
        if stalePlaybackErrorDetails.exists {
            let stalePlaybackErrorCloseButton = app.buttons["关闭"]
            XCTAssertTrue(stalePlaybackErrorCloseButton.waitForExistence(timeout: 3), "旧播放错误没有关闭入口")
            stalePlaybackErrorCloseButton.click()
            XCTAssertTrue(stalePlaybackErrorDetails.waitForNonExistence(timeout: 3), "旧播放错误面板没有关闭")
        }
        deleteImportedFixtureIfPresent()

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

        // 文件选择器允许通过“前往文件夹”跳转到测试 bundle，再选中固定音频样本。
        pickerApp.typeKey("g", modifierFlags: [.command, .shift])
        let goToFolderField = pickerApp.textFields["PathTextField"]
        XCTAssertTrue(goToFolderField.waitForExistence(timeout: 5), "文件选择器没有显示路径输入框")
        goToFolderField.click()
        goToFolderField.typeKey("a", modifierFlags: .command)
        let fixtureFolderPath = try XCTUnwrap(fixtureURL).deletingLastPathComponent().path
        goToFolderField.typeText(fixtureFolderPath)
        XCTAssertEqual(goToFolderField.value as? String, fixtureFolderPath, "文件选择器未收到测试资源目录路径")
        pickerApp.typeKey(.return, modifierFlags: [])
        // macOS 27 的 Go To Folder 面板第一次 Return 只会选中自动补全路径，
        // 第二次 Return 才会实际跳转到目录。
        goToFolderField.typeKey(.return, modifierFlags: [])

        // Finder 按系统偏好可能隐藏文件扩展名，因此按主文件名定位。
        // 列表窄列还可能截断长文件名，使用足以区分样本的前缀。
        let fixtureRow = element(containing: String(fixtureName.prefix(18)))
        XCTAssertTrue(fixtureRow.waitForExistence(timeout: 10), "文件选择器未定位到测试音频")
        fixtureRow.doubleClick()

        XCTAssertTrue(pickerApp.windows.firstMatch.waitForNonExistence(timeout: 15) || app.dialogs.firstMatch.waitForNonExistence(timeout: 1), "文件选择器关闭前未完成测试音频导入")

        let trackTitle = fixtureName
        // 音乐仓库将整行暴露为 Button，而不是 StaticText。
        let track = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", trackTitle)).firstMatch
        XCTAssertTrue(track.waitForExistence(timeout: 30), "导入的测试音频未出现在音乐仓库：\(trackTitle)")
        track.click()

        // 播放中的控制按钮变为 Pause，是音频已进入播放态的公开 UI 证据。
        let pauseButton = app.buttons.matching(NSPredicate(format: "label == %@", "Pause")).firstMatch
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 15), "选择音频后播放器没有进入播放态")

        let playerTitle = element(identifier: "cisum.player.title")
        XCTAssertTrue(playerTitle.waitForExistence(timeout: 10), "播放时主播放器曲目标题没有显示")
        let titleMatchesCurrentTrack = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@ OR value == %@", fixtureName, fixtureName),
            object: playerTitle
        )
        XCTAssertEqual(XCTWaiter.wait(for: [titleMatchesCurrentTrack], timeout: 10), .completed, "主播放器标题没有反映当前播放曲目")
        XCTAssertEqual(playerTitle.value as? String ?? playerTitle.label, fixtureName, "主播放器标题没有反映当前播放曲目")

        let progress = element(identifier: "cisum.player.progress")
        XCTAssertTrue(progress.waitForExistence(timeout: 10), "播放时主播放器进度条没有显示")
        let progressAdvances = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value > 0"),
            object: progress
        )
        XCTAssertEqual(XCTWaiter.wait(for: [progressAdvances], timeout: 10), .completed, "播放进度没有随音频推进")

        pauseButton.click()

        let playButton = app.buttons.matching(NSPredicate(format: "label == %@", "Play")).firstMatch
        XCTAssertTrue(playButton.waitForExistence(timeout: 10), "点击暂停后播放器没有回到暂停态")
        playButton.click()
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 10), "恢复播放后播放器没有回到播放态")
        pauseButton.click()
        XCTAssertTrue(playButton.waitForExistence(timeout: 10), "第二次暂停后播放器状态不正确")

        // 删除此次导入的曲目，避免重复运行 UI 测试污染本地音乐仓库。
        deleteImportedFixtureIfPresent()
        XCTAssertTrue(track.waitForNonExistence(timeout: 15), "测试音频未从音乐仓库清理")
        #else
        throw XCTSkip("音频仓库文件夹播放回归当前仅在 macOS UI 测试中覆盖")
        #endif
    }

    #if os(macOS)
    private func deleteImportedFixtureIfPresent() {
        let track = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", fixtureName)).firstMatch
        guard track.exists else { return }

        track.rightClick()
        // SwiftUI 的 context-menu 项以 trash SF Symbol 暴露为 identifier。
        let deleteMenuItem = app.menuItems.matching(identifier: "trash").firstMatch
        XCTAssertTrue(deleteMenuItem.waitForExistence(timeout: 5), "曲目上下文菜单中没有删除命令")
        deleteMenuItem.click()

        let confirmDelete = app.buttons.matching(NSPredicate(format: "label IN %@", ["Delete", "删除"])).firstMatch
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), "删除确认没有出现")
        confirmDelete.click()
        XCTAssertTrue(track.waitForNonExistence(timeout: 15), "测试音频未从音乐仓库清理")
    }
    #endif
}

// MARK: - 音乐仓库内容区（原型 03）

/// 音乐仓库场景：列表呈现、表头统计、读取中/空状态。
final class CisumMusicLibraryUITests: CisumUITestBase {
    func testMusicLibrarySceneIsShown() throws {
        try ensureMusicScene()
        XCTAssertTrue(
            element(identifier: "cisum.scene.music").waitForExistence(timeout: 10),
            "音乐仓库内容区未出现"
        )
    }

    func testMusicLibraryShowsHeaderOrState() throws {
        try ensureMusicScene()
        XCTAssertTrue(element(identifier: "cisum.scene.music").waitForExistence(timeout: 10))

        // 有数据时显示表头 “Total N”；同步时显示 “Reading repository”；
        // 空仓库时显示空状态提示。任一出现即视为列表区域已渲染。
        let header = element(labelBeginsWith: ["Total", "共"])
        let reading = element(anyLabelOf: ["Reading repository", "正在读取仓库"])
        let emptyState = element(anyLabelOf: [
            "Drop music files here to add them",
            "将音乐文件拖到这里可添加",
            "Music repository is empty",
            "歌曲仓库为空",
        ])
        XCTAssertTrue(
            header.exists || reading.exists || emptyState.exists,
            "音乐仓库列表既无表头统计，也未显示读取中或空状态"
        )
    }

    func testMusicLibraryContentFitsCompactWindow() throws {
        #if os(macOS)
        app.activate()
        try ensureMusicScene()
        let window = app.windows["Cisum"]
        let scene = element(identifier: "cisum.scene.music")
        XCTAssertTrue(scene.waitForExistence(timeout: 10), "音乐仓库场景未出现")

        XCTAssertLessThanOrEqual(window.frame.width, 460, "测试启动窗口不处于紧凑宽度")
        assertMusicPlayerControlsFit(window: window)
        #else
        throw XCTSkip("窗口尺寸响应式布局测试仅 macOS 支持")
        #endif
    }

    #if os(macOS)
    private func assertMusicPlayerControlsFit(window: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let labels = ["More", "Previous", "Play", "Next", "Playback mode"]
        for label in labels {
            let button = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 10), "播放器按钮「\(label)」未稳定出现")
            assertElementFitsWindow(button, window: window, description: "播放器按钮「\(label)」", file: file, line: line)
        }
    }
    #endif
}

// MARK: - 有声书内容区（原型 04）

/// 有声书场景：场景进入、网格/列表呈现。
final class CisumAudiobooksUITests: CisumUITestBase {
    func testAudiobooksSceneCanBeEntered() throws {
        try ensureAudiobooksScene()
        XCTAssertTrue(
            element(identifier: "cisum.scene.audiobooks").waitForExistence(timeout: 10),
            "有声书内容区未出现"
        )
    }

    func testAudiobooksGridShowsBooksOrEmptyState() throws {
        try ensureAudiobooksScene()
        XCTAssertTrue(element(identifier: "cisum.scene.audiobooks").waitForExistence(timeout: 10))

        // 有数据时显示表头 “Total N” 或书卡（可访问性标签 “Select …”）；
        // 空仓库时显示空状态。
        let header = element(labelBeginsWith: ["Total", "共"])
        let bookTile = element(labelBeginsWith: ["Select ", "选择"])
        let reading = element(anyLabelOf: ["Reading repository", "正在读取仓库"])
        let emptyState = element(containing: "Drop audiobook folders here to add them")
            .exists || element(containing: "将有声书文件夹拖到这里可添加").exists
            || element(containing: "Audiobook repository is empty").exists
            || element(containing: "有声书仓库为空").exists
            || element(containing: "Repository is empty").exists
            || element(containing: "仓库为空").exists
        let unavailableState = element(identifier: "cisum.scene.audiobooks.unavailable")
        XCTAssertTrue(
            header.exists || bookTile.exists || reading.exists || emptyState || unavailableState.exists,
            "有声书网格既无表头统计、书卡，也未显示读取中或空状态"
        )
    }

    func testAudiobooksContentFitsCompactWindow() throws {
        #if os(macOS)
        app.activate()
        try ensureAudiobooksScene()
        let window = app.windows["Cisum"]
        let scene = element(identifier: "cisum.scene.audiobooks")
        XCTAssertTrue(scene.waitForExistence(timeout: 10), "有声书仓库场景未出现")

        XCTAssertLessThanOrEqual(window.frame.width, 460, "测试启动窗口不处于紧凑宽度")
        let emptyStateTitle = text(containing: [
            "Drop audiobook folders here to add them",
            "将有声书文件夹拖到这里可添加",
        ])
        let supportedFormats = text(containing: ["Supported formats:", "支持的格式"])
        assertElementFitsWindow(emptyStateTitle, window: window, description: "有声书空状态标题")
        assertElementFitsWindow(supportedFormats, window: window, description: "有声书支持格式说明")
        #else
        throw XCTSkip("窗口尺寸响应式布局测试仅 macOS 支持")
        #endif
    }
}

// MARK: - 设置窗口（原型 05）

/// 设置窗口：入口呈现、侧边栏导航与各设置页内容。
final class CisumSettingsUITests: CisumUITestBase {
    func testSettingsWindowShowsSidebarEntries() throws {
        #if os(macOS)
        openSettingsWindowViaMenu()
        XCTAssertTrue(
            element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15),
            "设置窗口未就绪"
        )

        // 侧边栏至少包含「通用」入口。
        let generalEntry = element(anyLabelOf: ["General", "通用"])
        XCTAssertTrue(generalEntry.waitForExistence(timeout: 5), "设置窗口缺少「通用」入口")
        #else
        throw XCTSkip("设置窗口仅 macOS 支持")
        #endif
    }

    func testSettingsStorageEntryShowsRepositoryInfo() throws {
        #if os(macOS)
        openSettingsWindowViaMenu()
        XCTAssertTrue(element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15))

        // 打开「存储设置」入口，验证媒体存储位置选择区。
        let storageEntry = element(anyLabelOf: ["Storage Settings", "存储设置", "音乐仓库"])
        XCTAssertTrue(storageEntry.waitForExistence(timeout: 5), "设置窗口缺少存储设置入口")
        storageEntry.click()

        XCTAssertTrue(
            element(identifier: "cisum.settings.storage.location").waitForExistence(timeout: 5),
            "存储设置页缺少「媒体存储位置」区块"
        )
        XCTAssertTrue(element(identifier: "cisum.settings.storage.icloud").exists, "缺少 iCloud 存储选项")
        XCTAssertTrue(element(identifier: "cisum.settings.storage.local").exists, "缺少本地存储选项")
        #else
        throw XCTSkip("设置窗口仅 macOS 支持")
        #endif
    }

    func testAppearanceSettingsShowsAvailableThemes() throws {
        #if os(macOS)
        openSettingsWindowViaMenu()
        XCTAssertTrue(element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15))

        let appearanceEntry = element(anyLabelOf: ["Appearance", "外观"])
        XCTAssertTrue(appearanceEntry.waitForExistence(timeout: 5), "设置窗口缺少外观设置入口")
        appearanceEntry.click()

        let themeCount = element(containing: "themes")
        XCTAssertTrue(themeCount.waitForExistence(timeout: 10), "外观页没有显示主题数量")
        XCTAssertFalse(
            element(anyLabelOf: ["0 themes", "0 个主题"]).exists,
            "外观页主题数为 0，主题插件贡献没有进入 ThemeProviding"
        )
        let themeSearch = app.textFields.matching(
            NSPredicate(format: "placeholderValue IN %@", ["Search Themes", "搜索主题"])
        ).firstMatch
        XCTAssertTrue(themeSearch.waitForExistence(timeout: 5), "外观页没有主题搜索入口")
        XCTAssertTrue(
            element(anyLabelOf: ["Use This Theme", "使用此主题", "Currently In Use", "当前使用", "目前使用"])
                .waitForExistence(timeout: 5),
            "外观页没有显示选中主题的应用状态"
        )
        #else
        throw XCTSkip("外观设置窗口仅 macOS 支持")
        #endif
    }
}

// MARK: - 复制任务状态（原型 06）

/// 复制任务：状态面板的呈现与消息格式。
/// 说明：XCUITest 无法在 macOS 上注入真实的文件拖拽事件，因此本组用例
/// 验证“有任务时面板正确呈现”与“无任务时面板不出现”，不模拟拖拽复制。
final class CisumCopyTaskUITests: CisumUITestBase {
    func testCopyStatusPanelIsHiddenWhenIdle() {
        let copyState = element(identifier: "cisum.copy.state")
        XCTAssertFalse(copyState.waitForExistence(timeout: 3), "无复制任务时不应显示复制状态面板")
    }
}

// MARK: - 场景切换器（原型 07）

/// 场景切换器：工具栏入口、场景选择器弹出、场景切换后内容区跟随变化。
final class CisumSceneSwitcherUITests: CisumUITestBase {
    func testSceneSwitcherOpensScenePicker() throws {
        #if os(macOS)
        let switcher = element(identifier: "cisum.scene.switcher")
        XCTAssertTrue(switcher.waitForExistence(timeout: 10), "工具栏找不到场景切换器")
        switcher.click()

        XCTAssertTrue(
            element(anyLabelOf: ["Music Library", "音乐仓库", "Audiobooks", "有声书"])
                .waitForExistence(timeout: 5),
            "场景选择器未弹出"
        )
        #else
        throw XCTSkip("场景切换器仅 macOS 支持")
        #endif
    }

    func testSceneSwitcherSwitchesBetweenScenes() throws {
        #if os(macOS)
        // 音乐 → 有声书。
        try ensureAudiobooksScene()
        XCTAssertTrue(
            element(identifier: "cisum.scene.audiobooks").waitForExistence(timeout: 10),
            "切换到有声书场景后内容区未更新"
        )

        // 有声书 → 音乐。
        try ensureMusicScene()
        XCTAssertTrue(
            element(identifier: "cisum.scene.music").waitForExistence(timeout: 10),
            "切回音乐场景后内容区未更新"
        )
        #else
        throw XCTSkip("场景切换器仅 macOS 支持")
        #endif
    }
}

// MARK: - 欢迎引导（原型 01）

/// 欢迎引导：媒体存储位置选择。
/// 仅当存储位置尚未配置时出现（首次启动）；已配置环境显式跳过。
final class CisumWelcomeUITests: CisumUITestBase {
    func testWelcomeGuideShowsStorageSelectionWhenUnconfigured() throws {
        let welcomeTitle = element(anyLabelOf: ["Good Things Are Coming", "精彩即将呈现"])
        guard welcomeTitle.waitForExistence(timeout: 5) else {
            throw XCTSkip("存储位置已配置，欢迎引导页未显示")
        }

        XCTAssertTrue(element(anyLabelOf: ["iCloud Drive", "iCloud 云盘"]).exists, "缺少 iCloud 云盘存储选项")
        XCTAssertTrue(element(anyLabelOf: ["App Local Storage", "应用本地存储"]).exists, "缺少应用本地存储选项")
    }
}
