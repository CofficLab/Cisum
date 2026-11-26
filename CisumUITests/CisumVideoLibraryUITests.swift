import XCTest

final class CisumVideoLibraryEmptyUITests: CisumUITestBase {
    override var additionalLaunchArguments: [String] {
        appendingLaunchArguments(["--cisum-ui-testing-scene=videos"])
            .filter { $0 != "--cisum-ui-testing-reset-scene" }
    }

    func testEmptyRepositoryFillsWindowWithSingleEmptyState() throws {
        try ensureVideoScene()

        let library = element(identifier: "cisum.video.library")
        XCTAssertTrue(library.waitForExistence(timeout: 10))
        XCTAssertTrue(element(anyLabelOf: ["No videos found", "未找到视频"]).waitForExistence(timeout: 15))
        XCTAssertFalse(element(identifier: "cisum.video.miniplayer").exists, "空仓库不应保留播放器")
        XCTAssertFalse(element(identifier: "cisum.video.progress").exists, "空仓库不应保留无效进度条")
        XCTAssertFalse(element(containing: "/cisum-ui-testing/").exists, "媒体库不应展示完整仓库路径")
        XCTAssertFalse(element(anyLabelOf: ["No matching videos", "没有匹配的视频"]).exists)
        attachScreenshot(named: "Video library - empty repository")

        #if os(macOS)
        let window = mainWindow
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(
            library.frame.height,
            window.frame.height * 0.8,
            "视频库应铺满窗口，而不是挤在播放器下方的内容区"
        )
        XCTAssertTrue(element(identifier: "cisum.video.sidebar").waitForExistence(timeout: 5))
        XCTAssertTrue(element(identifier: "cisum.video.title").waitForExistence(timeout: 5))
        XCTAssertEqual(
            app.descendants(matching: .any).matching(identifier: "cisum.video.title").count,
            1,
            "macOS 页头只保留一处视频库标题"
        )
        #else
        XCTAssertFalse(element(identifier: "cisum.video.sidebar").exists, "窄布局的侧栏默认收起")
        let toggle = element(identifier: "cisum.video.sidebar.toggle")
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        assertButtonHasMinimumTapTarget(toggle, description: "侧栏按钮")
        toggle.cisumActivate()
        XCTAssertTrue(element(identifier: "cisum.video.scope.all").waitForExistence(timeout: 5))
        attachScreenshot(named: "Video library - compact sidebar")
        #endif
    }

    func testCompactActionsRemainAvailableInsideVisibleBounds() throws {
        try ensureVideoScene()

        let displayMode = element(identifier: "cisum.video.displaymode")
        XCTAssertTrue(displayMode.waitForExistence(timeout: 10))

        #if os(macOS)
        XCTAssertTrue(element(identifier: "cisum.video.search").waitForExistence(timeout: 5))
        XCTAssertTrue(element(identifier: "cisum.video.sort").waitForExistence(timeout: 5))
        let window = mainWindow
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        assertElementFitsWindow(displayMode, window: window, description: "视频显示模式")
        assertElementFitsWindow(element(identifier: "cisum.video.import"), window: window, description: "导入视频按钮")
        #else
        let filters = element(identifier: "cisum.video.filters")
        XCTAssertTrue(filters.waitForExistence(timeout: 5))
        assertElementFitsScreen(filters, description: "视频筛选入口")
        assertElementFitsScreen(displayMode, description: "视频显示模式")
        let importButton = element(identifier: "cisum.video.import")
        XCTAssertTrue(importButton.waitForExistence(timeout: 5))
        assertButtonHasMinimumTapTarget(importButton, description: "导入视频按钮")
        assertElementFitsScreen(importButton, description: "导入视频按钮")
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

    func testSelectionInspectorImmersivePlaybackAndMiniPlayer() throws {
        try ensureVideoScene()
        let item = element(identifier: "cisum.video.item.Cisum-UI-Video.mp4")
        XCTAssertTrue(item.waitForExistence(timeout: 20), "真实种子视频未进入媒体库")
        XCTAssertFalse(element(identifier: "cisum.video.miniplayer").exists, "未播放时不应出现播放器")

        #if os(macOS)
        item.click()
        let resume = element(identifier: "cisum.video.resume")
        XCTAssertTrue(resume.waitForExistence(timeout: 10), "单击视频后未打开检查器")
        attachScreenshot(named: "Video library - inspector")

        item.doubleClick()
        #else
        item.tap()
        #endif

        let player = element(identifier: "cisum.video.player")
        XCTAssertTrue(player.waitForExistence(timeout: 20), "打开视频后未进入沉浸播放")
        XCTAssertFalse(element(identifier: "cisum.video.playback-error").exists)
        attachScreenshot(named: "Video library - immersive playback")

        let close = element(identifier: "cisum.video.close")
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        #if !os(macOS)
        assertButtonHasMinimumTapTarget(close, description: "关闭沉浸播放按钮")
        #endif
        close.cisumActivate()

        XCTAssertTrue(waitForDisappearance(player), "关闭后沉浸播放器未退出")
        let miniPlayer = element(identifier: "cisum.video.miniplayer")
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 10), "关闭沉浸播放后未收成迷你播放器")
        XCTAssertTrue(element(identifier: "cisum.video.progress").waitForExistence(timeout: 5))
        attachScreenshot(named: "Video library - mini player")

        let expand = element(identifier: "cisum.video.expand")
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        #if !os(macOS)
        assertButtonHasMinimumTapTarget(expand, description: "展开播放按钮")
        #endif
        expand.cisumActivate()
        XCTAssertTrue(player.waitForExistence(timeout: 10), "从迷你播放器未能回到沉浸播放")
        element(identifier: "cisum.video.close").cisumActivate()
        XCTAssertTrue(waitForDisappearance(player, timeout: 10))

        let stop = element(identifier: "cisum.video.mini.stop")
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.cisumActivate()
        XCTAssertTrue(waitForDisappearance(miniPlayer), "停止播放后迷你播放器未退出")
        XCTAssertFalse(element(identifier: "cisum.video.playback-error").exists)
    }

    func testLeavingVideoSceneRestoresPlayerShell() throws {
        #if os(macOS)
        try ensureVideoScene()
        let library = element(identifier: "cisum.video.library")
        XCTAssertTrue(library.waitForExistence(timeout: 10))
        XCTAssertFalse(element(identifier: "cisum.player.controls").exists, "视频场景不应保留播放器外壳")

        try ensureMusicScene()
        XCTAssertTrue(waitForDisappearance(library, timeout: 10), "离开视频场景后资料库应撤下")
        XCTAssertTrue(element(identifier: "cisum.scene.music").waitForExistence(timeout: 10))
        XCTAssertTrue(element(identifier: "cisum.player.controls").waitForExistence(timeout: 10), "离开视频场景后播放器外壳应还原")

        try ensureVideoScene()
        XCTAssertTrue(library.waitForExistence(timeout: 10), "再次进入视频场景应重新登记资料库")
        attachScreenshot(named: "Video library - re-entered from music scene")
        #else
        throw XCTSkip("场景切换仅 macOS 支持")
        #endif
    }

    func testNoMatchesCanClearFiltersAndRestoreLibrary() throws {
        try ensureVideoScene()
        let item = element(identifier: "cisum.video.item.Cisum-UI-Video.mp4")
        XCTAssertTrue(item.waitForExistence(timeout: 20))

        #if os(macOS)
        let favorites = element(identifier: "cisum.video.scope.favorites")
        XCTAssertTrue(favorites.waitForExistence(timeout: 10))
        #else
        let filters = element(identifier: "cisum.video.filters")
        XCTAssertTrue(filters.waitForExistence(timeout: 10))
        filters.cisumActivate()
        let favorites = element(identifier: "cisum.video.scope.favorites")
        XCTAssertTrue(favorites.waitForExistence(timeout: 5))
        #endif
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
