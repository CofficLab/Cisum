import XCTest

/// 存储位置切换的 UI 覆盖。
///
/// 背景：此前只验证了「存储设置页有 iCloud / 本地两个选项」，
/// **没有验证切换真的能生效**。存储位置决定仓库落在哪儿——切不动的话，
/// 用户要么找不到自己的媒体，要么以为数据丢了。
///
/// 本文件锁定三条用户可见契约：
/// 1. 存储设置页展示当前仓库路径；
/// 2. 点击「本地」选项会进入迁移流程（弹出迁移进度面板）；
/// 3. 存储区块内的控件都完整落在设置窗口内。
final class CisumStorageLocationUITests: CisumUITestBase {
    /// 打开设置窗口并进入「存储设置」页。
    private func openStorageSettings() throws {
        #if os(macOS)
        openSettingsWindowViaMenu()
        XCTAssertTrue(element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15), "设置窗口未就绪")

        // 按 **button 类型**匹配：按 `.any` 匹配会先命中同名的说明文字。
        let entry = app.buttons.matching(
            NSPredicate(format: "label IN %@", ["Storage Settings", "存储设置", "音乐仓库"])
        ).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "设置窗口缺少存储设置入口")
        entry.click()

        XCTAssertTrue(
            element(identifier: "cisum.settings.storage.location").waitForExistence(timeout: 10),
            "存储设置页缺少「媒体存储位置」区块"
        )
        #else
        throw XCTSkip("存储设置页检查仅 macOS 设置窗口支持")
        #endif
    }

    /// 存储区块必须展示当前仓库路径（否则用户不知道媒体存在哪儿）。
    func testStoragePageShowsCurrentRepositoryPath() throws {
        try openStorageSettings()

        // 设置行的可访问标签是「标题、描述」拼接（如
        // 「打开当前的仓库、/Users/…/Documents」），因此按**包含**匹配；
        // 等值 / 前缀匹配都找不到。
        let openRepository = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "label CONTAINS %@ OR label CONTAINS %@ OR value CONTAINS %@ OR value CONTAINS %@",
                "Open Current Repository", "打开当前的仓库", "Open Current Repository", "打开当前的仓库"
            )
        ).firstMatch
        XCTAssertTrue(
            openRepository.waitForExistence(timeout: 10),
            "存储设置页缺少「打开当前的仓库」入口"
        )
    }

    /// 本地存储选项必须可用（当前测试以本地存储启动）。
    func testLocalStorageOptionIsAvailable() throws {
        try openStorageSettings()

        let localOption = element(identifier: "cisum.settings.storage.local")
        XCTAssertTrue(localOption.waitForExistence(timeout: 10), "存储设置页缺少本地存储选项")
        XCTAssertFalse(
            element(anyLabelOf: ["Unavailable", "不可用"]).exists,
            "本地存储在测试环境下不应显示为不可用"
        )
    }

    /// 点击「另一个」存储位置应进入迁移流程。
    ///
    /// 迁移面板是切换的必经之路：它负责把已有媒体搬到新位置。
    /// 若点击后什么都没发生，用户会以为切换失败。
    ///
    /// 注意：点击**当前**位置不会弹面板——那不是切换，是重复选中当前项，
    /// 应用据此直接返回。因此这里要点「与当前不同的那个位置」。
    func testSelectingAnotherStorageLocationStartsMigration() throws {
        try openStorageSettings()

        // 当前是本地（UI 测试以 `--cisum-ui-testing-storage-local` 启动）。
        let current = element(identifier: "cisum.settings.storage.local")
        XCTAssertTrue(current.waitForExistence(timeout: 10), "存储设置页缺少本地存储选项")

        // 找一个「与当前不同」的位置：iCloud 可用就用 iCloud。
        let icloud = element(identifier: "cisum.settings.storage.icloud")
        guard icloud.exists else {
            throw XCTSkip("iCloud 不可用，无法验证位置切换")
        }

        icloud.click()

        // 迁移进度以 sheet 形式呈现。
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(
            sheet.waitForExistence(timeout: 15),
            "点击「iCloud」后没有弹出迁移进度面板——切换存储位置无法完成"
        )
    }

    /// 点击**当前**存储位置不应弹出迁移面板（重复选中不是切换）。
    func testSelectingCurrentStorageLocationDoesNotStartMigration() throws {
        try openStorageSettings()

        let current = element(identifier: "cisum.settings.storage.local")
        XCTAssertTrue(current.waitForExistence(timeout: 10), "存储设置页缺少本地存储选项")

        current.click()

        // 迁移面板不应出现。
        XCTAssertFalse(
            app.sheets.firstMatch.waitForExistence(timeout: 3),
            "点击当前存储位置不应弹出迁移面板"
        )
    }

    /// 存储区块内的控件必须完整落在设置窗口内。
    func testStorageControlsFitInsideSettingsWindow() throws {
        #if os(macOS)
        try openStorageSettings()

        let window = app.windows.matching(identifier: "cisum.settings").firstMatch
        guard window.exists else {
            throw XCTSkip("设置窗口不可用")
        }

        let locationSection = element(identifier: "cisum.settings.storage.location")
        XCTAssertTrue(locationSection.exists, "存储位置区块未渲染")

        for identifier in ["cisum.settings.storage.icloud", "cisum.settings.storage.local"] {
            let control = element(identifier: identifier)
            XCTAssertTrue(control.exists, "存储选项 \(identifier) 未渲染")
            assertElementFitsWindow(
                control,
                window: window,
                description: "存储选项 \(identifier)"
            )
        }
        #else
        throw XCTSkip("存储布局检查仅 macOS 支持")
        #endif
    }
}
