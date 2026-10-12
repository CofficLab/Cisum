import XCTest

/// 欢迎引导：媒体存储位置选择。
final class CisumWelcomeUITests: CisumUITestBase {
    override var additionalLaunchArguments: [String] {
        ["--cisum-ui-testing", "--cisum-ui-testing-reset-storage"]
    }

    func testFirstLaunchRequiresStorageSelectionAndDismissesAfterChoosingLocal() throws {
        let setup = element(identifier: "cisum.welcome.storage.setup")
        XCTAssertTrue(setup.waitForExistence(timeout: 10), "首次启动应阻止进入主界面并要求选择存储位置")
        XCTAssertTrue(element(identifier: "cisum.welcome.storage.option.local").exists, "缺少应用本地存储选项")

#if os(iOS)
        let window = app.windows.firstMatch
        let title = element(anyLabelOf: ["Choose Your Media Storage", "选择媒体存储位置"])
        XCTAssertTrue(title.waitForExistence(timeout: 5), "欢迎页标题未出现")
        XCTAssertTrue(
            window.frame.insetBy(dx: -2, dy: -2).contains(title.frame),
            "欢迎页标题超出屏幕：title=\(title.frame), window=\(window.frame)"
        )
#endif

        let localStorage = element(identifier: "cisum.welcome.storage.option.local")
#if os(macOS)
        localStorage.click()
#else
        localStorage.tap()
#endif
        let setupGone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: setup)
        XCTAssertEqual(XCTWaiter.wait(for: [setupGone], timeout: 10), .completed, "保存存储位置后引导应自动关闭")
        XCTAssertTrue(element(identifier: "cisum.scene.music").waitForExistence(timeout: 10), "完成引导后音乐仓库未就绪")
        XCTAssertFalse(element(containing: "音频仓库不可用").exists, "配置存储时不应被通用仓库错误弹窗打断")
    }
}

final class CisumConfiguredWelcomeUITests: CisumUITestBase {
    func testExistingStorageSkipsWelcomeGuide() {
        XCTAssertFalse(element(identifier: "cisum.welcome.storage.setup").waitForExistence(timeout: 2), "已有有效存储位置时不应重复展示首次启动引导")
    }
}
