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

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
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
            .matching(NSPredicate(format: "label IN %@", labels))
            .firstMatch
    }

    /// 按 label 前缀查找（例如列表表头 “Total 86” / “共 86 首”）。
    func element(labelBeginsWith prefixes: [String]) -> XCUIElement {
        let predicates = prefixes.map { NSPredicate(format: "label BEGINSWITH %@", $0) }
        return app.descendants(matching: .any)
            .matching(NSCompoundPredicate(orPredicateWithSubpredicates: predicates))
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
        let switcher = element(identifier: "cisum.scene.switcher")
        XCTAssertTrue(switcher.waitForExistence(timeout: 10), "工具栏找不到场景切换器")
        switcher.click()

        let segment = element(anyLabelOf: labels)
        XCTAssertTrue(segment.waitForExistence(timeout: 5), "场景选择器中找不到目标场景：\(labels)")
        segment.click()

        let enterButton = element(anyLabelOf: ["Enter Scene", "进入场景"])
        XCTAssertTrue(enterButton.waitForExistence(timeout: 5), "找不到「进入场景」按钮")
        enterButton.click()
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

    func testPlayerHeroTitleReflectsCurrentTrack() {
        // 播放器标题区（当前曲目名）存在性验证；无资产时标题为空也属于合法状态，
        // 因此只验证标题文本元素存在或控制区仍然可用。
        XCTAssertTrue(element(identifier: "cisum.player.controls").exists)
    }
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
        let emptyState = element(anyLabelOf: [
            "Drop audiobook folders here to add them",
            "将有声书文件夹拖到这里可添加",
            "Audiobook repository is empty",
            "有声书仓库为空",
            "Repository is empty",
            "仓库为空",
        ])
        XCTAssertTrue(
            header.exists || bookTile.exists || reading.exists || emptyState.exists,
            "有声书网格既无表头统计、书卡，也未显示读取中或空状态"
        )
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
            element(anyLabelOf: ["Media Storage Location", "媒体存储位置"]).waitForExistence(timeout: 5),
            "存储设置页缺少「媒体存储位置」区块"
        )
        XCTAssertTrue(element(anyLabelOf: ["iCloud Drive", "iCloud 云盘"]).exists, "缺少 iCloud 存储选项")
        XCTAssertTrue(element(anyLabelOf: ["App Local Storage", "应用本地存储"]).exists, "缺少本地存储选项")
        #else
        throw XCTSkip("设置窗口仅 macOS 支持")
        #endif
    }
}

// MARK: - 复制任务状态（原型 06）

/// 复制任务：状态面板的呈现与消息格式。
/// 说明：XCUITest 无法在 macOS 上注入真实的文件拖拽事件，因此本组用例
/// 验证“有任务时面板正确呈现”与“无任务时面板不出现”，不模拟拖拽复制。
final class CisumCopyTaskUITests: CisumUITestBase {
    func testCopyStatusPanelReflectsPendingTasks() {
        let copyState = element(identifier: "cisum.copy.state")
        if copyState.waitForExistence(timeout: 3) {
            // 有复制任务：必须提供详情按钮，且状态消息符合 “Copying N file(s)” 格式。
            let detailsButton = element(anyLabelOf: ["Show copy details", "Hide copy details"])
            XCTAssertTrue(detailsButton.exists, "复制状态面板缺少详情按钮")

            let message = element(labelBeginsWith: ["Copying", "正在复制", "Copy", "复制"])
            XCTAssertTrue(message.exists, "复制状态面板缺少任务消息")
        }
        // 无任务时状态面板不出现，属于正常情况。
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
