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

        let header = element(labelBeginsWith: ["Total", "共"])
        let reading = element(anyLabelOf: ["Reading repository", "正在读取仓库"])
        let emptyState = element(anyLabelOf: [
            "Drop music files here to add them",
            "将音乐文件拖到这里可添加",
            "Music repository is empty",
            "歌曲仓库为空",
        ])
        XCTAssertTrue(header.exists || reading.exists || emptyState.exists, "音乐仓库列表既无表头统计，也未显示读取中或空状态")
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

    func testMusicLibraryFileRowFitsCompactWindow() throws {
        #if os(macOS)
        app.activate()
        try ensureMusicScene()
        let window = app.windows["Cisum"]
        XCTAssertTrue(window.waitForExistence(timeout: 10), "主窗口未出现，无法检查音乐列表布局")

        let track = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", layoutRegressionAudioName)).firstMatch
        XCTAssertTrue(track.waitForExistence(timeout: 30), "UI 测试种子音频未出现在音乐仓库：\(layoutRegressionAudioName)")
        let trackFrame = track.frame
        XCTAssertTrue(
            window.frame.insetBy(dx: -2, dy: -2).contains(trackFrame),
            "音乐文件列表行超出主窗口：label=\(track.label), element=\(trackFrame), window=\(window.frame)"
        )
        XCTAssertTrue(track.label.contains(layoutRegressionAudioName), "音乐文件列表行的可访问性标签缺少完整文件名")
        #else
        throw XCTSkip("音乐列表窗口布局回归仅在 macOS UI 测试中覆盖")
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
