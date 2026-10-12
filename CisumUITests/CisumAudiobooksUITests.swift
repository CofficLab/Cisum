import XCTest

/// 有声书场景：场景进入、网格/列表呈现。
final class CisumAudiobooksUITests: CisumUITestBase {
    func testAudiobooksSceneCanBeEntered() throws {
        try ensureAudiobooksScene()
        XCTAssertTrue(element(identifier: "cisum.scene.audiobooks").waitForExistence(timeout: 10), "有声书内容区未出现")
    }

    func testAudiobooksGridShowsBooksOrEmptyState() throws {
        try ensureAudiobooksScene()
        XCTAssertTrue(element(identifier: "cisum.scene.audiobooks").waitForExistence(timeout: 10))

        let header = element(labelBeginsWith: ["Total", "共"])
        let bookTile = element(labelBeginsWith: ["Select ", "选择"])
        let reading = element(anyLabelOf: ["Reading repository", "正在读取仓库"])
        let emptyState = element(containing: "Drop audiobook folders here to add them").exists
            || element(containing: "将有声书文件夹拖到这里可添加").exists
            || element(containing: "Audiobook repository is empty").exists
            || element(containing: "有声书仓库为空").exists
            || element(containing: "Repository is empty").exists
            || element(containing: "仓库为空").exists
        let unavailableState = element(identifier: "cisum.scene.audiobooks.unavailable")
        XCTAssertTrue(header.exists || bookTile.exists || reading.exists || emptyState || unavailableState.exists, "有声书网格既无表头统计、书卡，也未显示读取中或空状态")
    }

    func testAudiobooksContentFitsCompactWindow() throws {
        #if os(macOS)
        app.activate()
        try ensureAudiobooksScene()
        let window = app.windows["Cisum"]
        let scene = element(identifier: "cisum.scene.audiobooks")
        XCTAssertTrue(scene.waitForExistence(timeout: 10), "有声书仓库场景未出现")
        XCTAssertLessThanOrEqual(window.frame.width, 460, "测试启动窗口不处于紧凑宽度")

        let emptyStateTitle = text(containing: ["Drop audiobook folders here to add them", "将有声书文件夹拖到这里可添加"])
        let supportedFormats = text(containing: ["Supported formats:", "支持的格式"])
        assertElementFitsWindow(emptyStateTitle, window: window, description: "有声书空状态标题")
        assertElementFitsWindow(supportedFormats, window: window, description: "有声书支持格式说明")
        #else
        throw XCTSkip("窗口尺寸响应式布局测试仅 macOS 支持")
        #endif
    }
}
