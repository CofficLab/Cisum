import XCTest

/// 设置窗口导航结构的 UI 覆盖。
///
/// 背景：设置侧边栏是用户进入全部子设置的唯一路径。此前没有任何 UI 测试
/// 断言过「侧边栏有哪些入口」「点击入口能切到对应页面」——入口消失或
/// 点击失效时，用户只能看到空白设置页。
///
/// ## 关于「插件管理」入口
///
/// `PluginPluginManager` 采用默认的 `.required` 策略；书库、视频库、欢迎页、
/// 仓库引导等模块是用户可配置插件，因此「插件管理」入口会出现在设置侧边栏。
/// 本文件据此断言**当前确实存在**的五个入口：
/// 通用 / 外观 / 插件管理 / 存储设置 / 商店。
final class CisumSettingsNavigationUITests: CisumUITestBase {
    /// 设置侧边栏当前应当存在的入口（按 `order` 升序）。
    ///
    /// - 通用：order 1（`SettingGeneralPlugin`）
    /// - 外观：order 2（`CisumThemeBridge`）
    /// - 插件管理：order 3（`PluginPluginManager`）
    /// - 存储设置：`StoragePlugin`
    /// - 商店：order 80（`StorePlugin`）
    private static let expectedEntries: [(labels: [String], id: String)] = [
        (["General", "通用"], "general"),
        (["Appearance", "外观"], "appearance"),
        (["Plugin Manager", "插件管理"], "plugin-manager"),
        (["Storage Settings", "存储设置", "音乐仓库"], "storage"),
        (["Store", "商店"], "store"),
    ]

    /// 打开设置窗口并返回侧边栏。
    private func openSettingsSidebar() throws {
        #if os(macOS)
        openSettingsWindowViaMenu()
        XCTAssertTrue(
            element(identifier: "cisum.settings.ready").waitForExistence(timeout: 15),
            "设置窗口未就绪"
        )
        #else
        throw XCTSkip("设置侧边栏仅 macOS 设置窗口支持")
        #endif
    }

    /// 侧边栏按钮（按类型匹配，避免命中同名说明文字）。
    private func sidebarButton(labels: [String]) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label IN %@", labels)
        ).firstMatch
    }

    // MARK: - 入口完整性

    /// 设置侧边栏必须包含全部五个入口。
    ///
    /// 少一个入口就意味着对应的功能在设置里彻底找不到。
    func testSidebarContainsAllExpectedEntries() throws {
        try openSettingsSidebar()

        for entry in Self.expectedEntries {
            let button = sidebarButton(labels: entry.labels)
            XCTAssertTrue(
                button.waitForExistence(timeout: 10),
                "设置侧边栏缺少入口「\(entry.labels.first ?? "")」"
            )
        }
    }

    /// 侧边栏必须暴露「插件管理」入口。
    ///
    /// `PluginPluginManager` 已启用，且插件目录里存在用户可配置插件；
    /// 入口一旦消失，用户就失去了启停功能模块的唯一路径。
    func testSidebarExposesPluginManagerEntry() throws {
        try openSettingsSidebar()

        let pluginManager = sidebarButton(labels: ["Plugin Manager", "插件管理"])
        XCTAssertTrue(
            pluginManager.waitForExistence(timeout: 10),
            "「插件管理」入口未出现在设置侧边栏"
        )
    }

    // MARK: - 导航

    /// 点击每个入口都能切换到对应页面（详情区内容随之变化）。
    func testEachSidebarEntryNavigatesToItsPage() throws {
        try openSettingsSidebar()

        for entry in Self.expectedEntries {
            let button = sidebarButton(labels: entry.labels)
            guard button.waitForExistence(timeout: 10) else {
                XCTFail("设置侧边栏缺少入口「\(entry.labels.first ?? "")」")
                continue
            }

            button.cisumActivate()

            // 详情区必须出现内容（不是空白页）。
            let detail = app.scrollViews.element(boundBy: 1)
            XCTAssertTrue(
                detail.waitForExistence(timeout: 10),
                "点击「\(entry.labels.first ?? "")」后详情区没有渲染"
            )

            // 设置窗口本身不能因此消失。
            XCTAssertTrue(
                element(identifier: "cisum.settings.ready").exists,
                "点击「\(entry.labels.first ?? "")」后设置窗口消失了"
            )
        }
    }

    /// 入口在侧边栏中必须完整可见（不被裁切）。
    func testSidebarEntriesFitInsideSettingsWindow() throws {
        #if os(macOS)
        try openSettingsSidebar()

        let window = app.windows.matching(identifier: "cisum.settings").firstMatch
        guard window.exists else {
            throw XCTSkip("设置窗口不可用")
        }

        for entry in Self.expectedEntries {
            let button = sidebarButton(labels: entry.labels)
            guard button.waitForExistence(timeout: 10) else { continue }
            assertElementFitsWindow(
                button,
                window: window,
                description: "设置侧边栏入口「\(entry.labels.first ?? "")」"
            )
        }
        #else
        throw XCTSkip("设置侧边栏布局检查仅 macOS 支持")
        #endif
    }
}
