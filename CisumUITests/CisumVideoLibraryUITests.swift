import XCTest

final class CisumVideoLibraryEmptyUITests: CisumUITestBase {
    override var additionalLaunchArguments: [String] {
        appendingLaunchArguments(["--cisum-ui-testing-scene=videos"])
            .filter { $0 != "--cisum-ui-testing-reset-scene" }
    }

    func testEmptyRepositoryUsesCompactControlAreaAndSingleEmptyState() throws {
        try ensureVideoScene()

        let library = element(identifier: "cisum.video.library")
        XCTAssertTrue(library.waitForExistence(timeout: 10))
        XCTAssertTrue(element(anyLabelOf: ["No videos found", "未找到视频"]).waitForExistence(timeout: 15))
        XCTAssertFalse(element(identifier: "cisum.video.hero").exists, "空仓库不应保留大块播放画面")
        XCTAssertFalse(element(identifier: "cisum.video.progress").exists, "空仓库不应保留无效进度条")
        XCTAssertFalse(element(containing: "/cisum-ui-testing/").exists, "媒体库不应展示完整仓库路径")
        XCTAssertFalse(element(anyLabelOf: ["No matching videos", "没有匹配的视频"]).exists)

        let controls = element(identifier: "cisum.video.controls")
        XCTAssertTrue(controls.waitForExistence(timeout: 5))
        XCTAssertLessThan(controls.frame.height, 200, "空仓库控制区应折叠到紧凑高度")
        attachScreenshot(named: "Video library - empty repository")

        #if os(macOS)
        let repeatedTitles = app.staticTexts.matching(NSPredicate(format: "label IN %@", ["Video Library", "视频库"]))
        XCTAssertEqual(repeatedTitles.count, 0, "macOS 内容区不应重复显示页面标题")
        #endif
    }

    func testCompactActionsRemainAvailableInsideVisibleBounds() throws {
        try ensureVideoScene()

        let filters = element(identifier: "cisum.video.filters")
        let displayMode = element(identifier: "cisum.video.displaymode")
        XCTAssertTrue(filters.waitForExistence(timeout: 10))
        XCTAssertTrue(displayMode.waitForExistence(timeout: 5))

        #if os(macOS)
        XCTAssertTrue(element(identifier: "cisum.video.search").waitForExistence(timeout: 5))
        let window = mainWindow
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        assertElementFitsWindow(filters, window: window, description: "视频筛选入口")
        assertElementFitsWindow(displayMode, window: window, description: "视频显示模式")
        #else
        assertElementFitsScreen(filters, description: "视频筛选入口")
        assertElementFitsScreen(displayMode, description: "视频显示模式")
        let importButton = element(identifier: "cisum.video.import")
        XCTAssertTrue(importButton.waitForExistence(timeout: 5))
        assertButtonHasMinimumTapTarget(importButton, description: "导入视频按钮")
        #endif
    }
}

final class CisumVideoLibraryPlaybackUITests: CisumUITestBase {
    override var additionalLaunchArguments: [String] {
        appendingLaunchArguments([
            "--cisum-ui-testing-scene=videos",
            "--cisum-ui-testing-seed-video",
            "Cisum-UI-Video.mp4",
        ])
        .filter { $0 != "--cisum-ui-testing-reset-scene" }
    }

    func testSelectionEmbeddedPlaybackAndImmersiveDismissal() throws {
        try ensureVideoScene()
        let item = element(identifier: "cisum.video.item.Cisum-UI-Video.mp4")
        XCTAssertTrue(item.waitForExistence(timeout: 20), "真实种子视频未进入媒体库")

        let hero = element(identifier: "cisum.video.hero")
        let progress = element(identifier: "cisum.video.progress")
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        XCTAssertTrue(element(anyLabelOf: ["Select a video to start playing", "选择一个视频开始播放"]).waitForExistence(timeout: 5))
        XCTAssertTrue(waitForNonExistence(progress, timeout: 2), "未选择媒体时不应显示播放进度")

        item.cisumActivate()

        let expand = element(identifier: "cisum.video.expand")
        XCTAssertTrue(expand.waitForExistence(timeout: 20), "选择视频后未加载内嵌播放器")
        #if !os(macOS)
        assertButtonHasMinimumTapTarget(expand, description: "展开播放按钮")
        #endif
        XCTAssertTrue(progress.waitForExistence(timeout: 10), "加载媒体后应显示播放进度")
        XCTAssertFalse(element(identifier: "cisum.video.playback-error").exists)
        attachScreenshot(named: "Video library - embedded playback")

        expand.cisumActivate()

        let player = element(identifier: "cisum.video.player")
        XCTAssertTrue(player.waitForExistence(timeout: 10), "显式展开后未进入沉浸播放")
        XCTAssertFalse(expand.exists, "沉浸播放不应同时保留内嵌播放器的展开控件")
        attachScreenshot(named: "Video library - immersive playback")

        let close = element(identifier: "cisum.video.close")
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        #if !os(macOS)
        assertButtonHasMinimumTapTarget(close, description: "关闭沉浸播放按钮")
        #endif
        close.cisumActivate()

        XCTAssertTrue(waitForDisappearance(player), "关闭后沉浸播放器未退出")
        XCTAssertTrue(expand.waitForExistence(timeout: 10), "关闭沉浸播放后未恢复内嵌播放器")
        XCTAssertTrue(progress.exists)
        XCTAssertFalse(element(identifier: "cisum.video.playback-error").exists)
    }

    func testNoMatchesCanClearFiltersAndRestoreLibrary() throws {
        try ensureVideoScene()
        let item = element(identifier: "cisum.video.item.Cisum-UI-Video.mp4")
        XCTAssertTrue(item.waitForExistence(timeout: 20))

        let filters = element(identifier: "cisum.video.filters")
        XCTAssertTrue(filters.waitForExistence(timeout: 10))
        filters.cisumActivate()
        let favorites = element(identifier: "cisum.video.scope.favorites")
        XCTAssertTrue(favorites.waitForExistence(timeout: 5))
        favorites.cisumActivate()

        XCTAssertTrue(element(anyLabelOf: ["No matching videos", "没有匹配的视频"]).waitForExistence(timeout: 10))
        XCTAssertFalse(item.exists)

        let clear = element(anyLabelOf: ["Clear Filters", "清除筛选"])
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        clear.cisumActivate()
        XCTAssertTrue(item.waitForExistence(timeout: 10), "清除筛选后未恢复视频条目")
        XCTAssertFalse(element(anyLabelOf: ["No matching videos", "没有匹配的视频"]).exists)
    }
}
