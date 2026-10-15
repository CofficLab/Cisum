import XCTest

/// 音乐仓库场景：列表呈现、表头统计、读取中/空状态。
final class CisumMusicLibraryUITests: CisumUITestBase {
    private let layoutRegressionAudioName = "Cisum-UI-Playback-Test-Tone-Long-Name-For-List-Layout.wav"

    override var additionalLaunchArguments: [String] {
        super.additionalLaunchArguments + ["--cisum-ui-testing-seed-audio", layoutRegressionAudioName]
    }

    func testMusicLibrarySceneIsShown() throws {
        try ensureMusicScene()
        XCTAssertTrue(element(identifier: "cisum.scene.music").waitForExistence(timeout: 10), "音乐仓库内容区未出现")
    }

    func testMusicLibraryShowsHeaderOrState() throws {
        try ensureMusicScene()
        XCTAssertTrue(element(identifier: "cisum.scene.music").waitForExistence(timeout: 10))

        // 表头 / 读取中 / 空状态是首屏异步加载的产物：iOS 上后台 SwiftData
        // 首次扫描比 macOS 慢，单次即时断言会稳定踩在加载窗口里。用 10s 的
        // 轮询等待任一状态出现，超时才判定失败。
        let candidates = [
            element(labelBeginsWith: ["Total", "共"]),
            element(anyLabelOf: ["Reading repository", "正在读取仓库"]),
            element(anyLabelOf: [
                "Drop music files here to add them",
                "将音乐文件拖到这里可添加",
                "Music repository is empty",
                "歌曲仓库为空",
            ]),
        ]
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if candidates.contains(where: { $0.exists }) { return }
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTFail("音乐仓库列表既无表头统计，也未显示读取中或空状态")
    }

    func testMusicLibraryContentFitsCompactWindow() throws {
        #if os(macOS)
        app.activate()
        #endif
        try ensureMusicScene()
        let window = mainWindow
        let scene = element(identifier: "cisum.scene.music")
        XCTAssertTrue(scene.waitForExistence(timeout: 10), "音乐仓库场景未出现")

        #if os(macOS)
        XCTAssertLessThanOrEqual(window.frame.width, 460, "测试启动窗口不处于紧凑宽度")
        #endif

        assertMusicPlayerControlsFit(window: window)
    }

    func testMusicLibraryFileRowFitsCompactWindow() throws {
        #if os(macOS)
        app.activate()
        #endif
        try ensureMusicScene()
        let window = mainWindow
        XCTAssertTrue(window.waitForExistence(timeout: 10), "主容器未出现，无法检查音乐列表布局")

        let track = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", layoutRegressionAudioName)).firstMatch
        XCTAssertTrue(track.waitForExistence(timeout: 30), "UI 测试种子音频未出现在音乐仓库：\(layoutRegressionAudioName)")
        let trackFrame = track.frame
        XCTAssertTrue(
            window.frame.insetBy(dx: -2, dy: -2).contains(trackFrame),
            "音乐文件列表行超出主容器：label=\(track.label), element=\(trackFrame), window=\(window.frame)"
        )
        XCTAssertTrue(track.label.contains(layoutRegressionAudioName), "音乐文件列表行的可访问性标签缺少完整文件名")
    }

    /// 播放器控制按钮必须完整落在可见边界内。
    ///
    /// 跨平台：macOS 校验主窗口，iOS 校验整屏（安全区内）。
    private func assertMusicPlayerControlsFit(window: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let labels = ["More", "Previous", "Play", "Next", "Playback mode"]
        for label in labels {
            let button = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 10), "播放器按钮「\(label)」未稳定出现")
            #if os(macOS)
            assertElementFitsWindow(button, window: window, description: "播放器按钮「\(label)」", file: file, line: line)
            #else
            assertElementFitsScreen(button, description: "播放器按钮「\(label)」", file: file, line: line)
            #endif
        }
    }
}
