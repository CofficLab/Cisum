import XCTest

// MARK: - Helpers

/// 读取元素的可见文本：macOS 的 `StaticText` 把文本放在 value，而不是 label。
private func visibleText(of element: XCUIElement) -> String {
    let label = element.label
    if !label.isEmpty { return label }
    return element.value as? String ?? ""
}

/// 等待元素的可见文本变成期望值（进度文本是异步爬升的）。
private func waitForVisibleText(_ element: XCUIElement, equals expected: String, timeout: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if element.exists, visibleText(of: element) == expected { return true }
        Thread.sleep(forTimeInterval: 0.25)
    }
    return element.exists && visibleText(of: element) == expected
}

/// 等待元素的可见文本包含某段文本（主题行会先从章节名补成「书名 + 章节位置」）。
private func waitForVisibleText(_ element: XCUIElement, containing text: String, timeout: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if element.exists, visibleText(of: element).contains(text) { return true }
        Thread.sleep(forTimeInterval: 0.25)
    }
    return element.exists && visibleText(of: element).contains(text)
}

/// 有声书 iCloud 载入横幅的 UI 行为。
///
/// 与音乐侧的 `CisumICloudDownloadUITests` 共用同一套注入网关：
/// - `--cisum-ui-testing-icloud-download=<timeout|success>` 让种子书籍的章节
///   在引擎里表现为「本地尚未缓存」；
/// - `--cisum-ui-testing-download-progress=0.42` 覆写进度快照，让 App 能呈现
///   确定的百分比。
///
/// 种子书籍走 `--cisum-ui-testing-seed-book`，不依赖系统文件选择器，
/// 因此这里覆盖的是「点击书卡 → 事件进入横幅」的整条链路。
final class CisumAudiobooksICloudBannerUITests: CisumUITestBase {
    private let seededBookName = "LoadingBook"
    private let seededChapterName = "Chapter 01"

    override var additionalLaunchArguments: [String] {
        appendingLaunchArguments([
            "--cisum-ui-testing-seed-book", "\(seededBookName)/\(seededChapterName).wav",
            "--cisum-ui-testing-icloud-download=timeout",
            "--cisum-ui-testing-download-progress=0.42",
        ])
    }

    private var banner: XCUIElement { element(identifier: "cisum.player.loading") }

    /// 进入有声书场景并点击种子书卡，触发一次需要等待 iCloud 的播放请求。
    private func openSeededBook() throws {
        try ensureAudiobooksScene()
        XCTAssertTrue(
            element(identifier: "cisum.scene.audiobooks").waitForExistence(timeout: 10),
            "有声书场景未出现"
        )
        waitForLibraryLoaded()

        let tile = element(containing: seededBookName)
        XCTAssertTrue(tile.waitForExistence(timeout: 10), "种子书 '\(seededBookName)' 未出现")
        tile.cisumActivate()

        XCTAssertTrue(
            banner.waitForExistence(timeout: 15),
            "点击书卡后没有出现 iCloud 载入横幅 cisum.player.loading"
        )
    }

    /// 等待元素的无障碍值包含某段文本（进度先是不确定，再变成具体百分比）。
    private func waitForValue(_ element: XCUIElement, containing text: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if (element.value as? String)?.contains(text) == true { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return (element.value as? String)?.contains(text) == true
    }

    /// 横幅必须同时说明「在做什么」「载的是哪一章」「进度多少」「能否取消」。
    func testBannerNamesChapterAndShowsInjectedProgress() throws {
        try openSeededBook()

        XCTAssertTrue(
            element(identifier: "cisum.player.loading.title").waitForExistence(timeout: 5),
            "横幅缺少标题行（正在从 iCloud 载入）"
        )
        let subject = element(identifier: "cisum.player.loading.subject")
        XCTAssertTrue(
            waitForVisibleText(subject, containing: seededBookName, timeout: 10),
            "横幅主题未指向正在载入的书：实际 \(visibleText(of: subject))"
        )

        let progress = element(identifier: "cisum.player.loading.progress")
        XCTAssertTrue(progress.waitForExistence(timeout: 5), "横幅缺少进度")
        XCTAssertTrue(
            waitForVisibleText(progress, equals: "42%", timeout: 10),
            "横幅进度与注入值不符：期望 42%，实际 \(visibleText(of: progress))"
        )

        XCTAssertTrue(
            element(identifier: "cisum.player.loading.cancel").exists,
            "横幅缺少取消入口"
        )
    }

    /// 被点击的书卡同步显示载入标注，且只有它带标注。
    func testTappedBookTileShowsLoadingBadge() throws {
        try openSeededBook()

        let badge = element(identifier: "cisum.book.download.badge")
        XCTAssertTrue(
            badge.waitForExistence(timeout: 10),
            "载入中的书卡没有出现标注 cisum.book.download.badge"
        )
        XCTAssertTrue(
            badge.label.contains(seededBookName),
            "书卡标注未指向被点击的书：\(badge.label)"
        )

        XCTAssertTrue(
            waitForValue(badge, containing: "42%", timeout: 10),
            "书卡标注的无障碍值缺少进度：\(badge.value as? String ?? "nil")"
        )
    }

    /// 取消只结束等待：横幅消失、不报错，且同一本书可以再次发起载入。
    func testCancelDismissesBannerQuietlyAndAllowsRetry() throws {
        try openSeededBook()

        let cancel = element(identifier: "cisum.player.loading.cancel")
        XCTAssertTrue(cancel.waitForExistence(timeout: 10), "横幅缺少取消按钮")
        cancel.cisumActivate()

        XCTAssertTrue(
            waitForDisappearance(banner, timeout: 5),
            "取消后载入横幅仍在显示"
        )
        XCTAssertFalse(
            element(identifier: "cisum.player.loading.error").exists,
            "取消被呈现成了载入失败"
        )

        element(containing: seededBookName).cisumActivate()
        XCTAssertTrue(
            banner.waitForExistence(timeout: 10),
            "取消后再次点击同一本书无法重新发起载入"
        )
    }
}

// MARK: - 超时失败

/// timeout 模式：8s 等待窗口结束后，横幅原地变成失败行，重试可再次发起载入。
final class CisumAudiobooksICloudFailureUITests: CisumUITestBase {
    private let seededBookName = "LoadingBook"

    override var additionalLaunchArguments: [String] {
        appendingLaunchArguments([
            "--cisum-ui-testing-seed-book", "\(seededBookName)/Chapter 01.wav",
            "--cisum-ui-testing-icloud-download=timeout",
        ])
    }

    private var banner: XCUIElement { element(identifier: "cisum.player.loading") }

    func testTimeoutTurnsBannerIntoFailureWithRetry() throws {
        try ensureAudiobooksScene()
        XCTAssertTrue(
            element(identifier: "cisum.scene.audiobooks").waitForExistence(timeout: 10),
            "有声书场景未出现"
        )
        waitForLibraryLoaded()

        let tile = element(containing: seededBookName)
        XCTAssertTrue(tile.waitForExistence(timeout: 10), "种子书 '\(seededBookName)' 未出现")
        tile.cisumActivate()

        XCTAssertTrue(
            banner.waitForExistence(timeout: 15),
            "点击书卡后没有出现 iCloud 载入横幅"
        )

        // 引擎的超时窗口是 8s，给足 20s 观察失败行。
        let errorRow = element(identifier: "cisum.player.loading.error")
        XCTAssertTrue(
            errorRow.waitForExistence(timeout: 20),
            "下载超时后横幅没有切换成失败行"
        )
        // 正文是可行动的人话；引擎原始原因只在 hint / help 里。
        let errorText = visibleText(of: errorRow)
        XCTAssertFalse(
            errorText.localizedCaseInsensitiveContains("timed out"),
            "失败文案直接暴露了引擎原始错误：\(errorText)"
        )

        let retry = element(identifier: "cisum.player.loading.retry")
        XCTAssertTrue(retry.exists, "失败行缺少重试按钮")
        retry.cisumActivate()

        XCTAssertTrue(
            waitForDisappearance(errorRow, timeout: 10),
            "点击重试后失败行没有消失"
        )
        XCTAssertTrue(
            element(identifier: "cisum.player.loading.title").waitForExistence(timeout: 10),
            "点击重试后没有重新进入载入态"
        )
    }
}
