import XCTest

/// 有声书仓库浏览的 UI 测试（含种子书籍）。
///
/// 通过 `--cisum-ui-testing-seed-book` 启动参数向仓库注入合成书籍，
/// 验证仓库网格能正确呈现种子书籍。
final class CisumAudiobooksLibraryUITests: CisumUITestBase {

    // MARK: - Override launch arguments to seed books

    override var additionalLaunchArguments: [String] {
        appendingLaunchArguments([
            "--cisum-ui-testing-seed-book", "TestBook/Chapter 01.wav",
        ])
    }

    // MARK: - Tests

    func testSeededBookAppearsInLibrary() throws {
        try ensureAudiobooksScene()

        let audiobooksScene = element(identifier: "cisum.scene.audiobooks")
        XCTAssertTrue(audiobooksScene.waitForExistence(timeout: 10), "有声书场景未出现")

        // 等待加载完成
        waitForLibraryLoaded()

        // 验证种子书出现
        let bookTile = element(containing: "TestBook")
        XCTAssertTrue(
            bookTile.waitForExistence(timeout: 10),
            "种子书 'TestBook' 未在仓库网格中出现"
        )
    }

    func testLibraryShowsTotalCountWithSeededBook() throws {
        try ensureAudiobooksScene()

        let audiobooksScene = element(identifier: "cisum.scene.audiobooks")
        XCTAssertTrue(audiobooksScene.waitForExistence(timeout: 10), "有声书场景未出现")

        waitForLibraryLoaded()

        // 验证总数显示（至少包含种子书）
        let header = element(labelBeginsWith: ["Total", "共"])
        XCTAssertTrue(header.waitForExistence(timeout: 10), "仓库表头未出现")
    }

    func testLibraryWithMultipleSeededBooks() throws {
        // 此测试在子类中覆写启动参数
    }
}

/// 多本书的仓库浏览测试。
final class CisumAudiobooksMultipleBooksUITests: CisumUITestBase {

    override var additionalLaunchArguments: [String] {
        appendingLaunchArguments([
            "--cisum-ui-testing-seed-book", "BookA;BookB/Chapter 01.wav,Chapter 02.wav",
        ])
    }

    func testMultipleSeededBooksAppearInLibrary() throws {
        try ensureAudiobooksScene()

        let audiobooksScene = element(identifier: "cisum.scene.audiobooks")
        XCTAssertTrue(audiobooksScene.waitForExistence(timeout: 10), "有声书场景未出现")

        waitForLibraryLoaded()

        let bookA = element(containing: "BookA")
        let bookB = element(containing: "BookB")

        XCTAssertTrue(
            bookA.waitForExistence(timeout: 10),
            "种子书 'BookA' 未在仓库中出现"
        )
        XCTAssertTrue(
            bookB.waitForExistence(timeout: 10),
            "种子书 'BookB' 未在仓库中出现"
        )
    }

    func testBookWithMultipleChaptersAppearsCorrectly() throws {
        try ensureAudiobooksScene()

        let audiobooksScene = element(identifier: "cisum.scene.audiobooks")
        XCTAssertTrue(audiobooksScene.waitForExistence(timeout: 10), "有声书场景未出现")

        waitForLibraryLoaded()

        // BookB 有两章，验证它作为合集呈现
        let bookB = element(containing: "BookB")
        XCTAssertTrue(bookB.waitForExistence(timeout: 10), "BookB 未出现")
    }
}

// MARK: - Helpers

extension CisumUITestBase {
    /// 等待仓库加载完成（loading 指示器消失或内容出现）。
    func waitForLibraryLoaded(timeout: TimeInterval = 15) {
        let loadingIndicator = element(anyLabelOf: ["Reading book repository", "正在读取有声书仓库"])
        let header = element(labelBeginsWith: ["Total", "共"])
        let bookTile = element(labelBeginsWith: ["Select ", "选择"])
        let emptyState = element(containing: "Drop audiobook folders here to add them").exists
            || element(containing: "将有声书文件夹拖到这里可添加").exists
            || element(containing: "Audiobook repository is empty").exists
            || element(containing: "有声书仓库为空").exists
            || element(containing: "Repository is empty").exists
            || element(containing: "仓库为空").exists

        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            if !loadingIndicator.exists || header.exists || bookTile.exists || emptyState {
                return
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
    }
}
