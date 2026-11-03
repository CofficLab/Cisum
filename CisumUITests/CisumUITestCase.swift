import Foundation
import XCTest

/// 所有 Cisum UI 测试的公共基类。
///
/// - 每个用例独立启动 App 并等待内核就绪（`cisum.kernel.ready`）。
/// - 元素查找优先使用产品公开的 accessibility identifier；对本地化文本
///   （中 / 英文 Scheme）提供双语言候选匹配。
/// - 设置入口测试仅适用于 macOS，其他平台显式跳过而非失败。
class CisumUITestBase: XCTestCase {
    var app: XCUIApplication!

    /// 启动参数。
    ///
    /// ## 默认隔离
    ///
    /// 默认参数里带 `--cisum-ui-testing-isolated-storage=<隔离目录名>`，
    /// 让本次启动的数据根落到临时目录下的独立子目录，与真实沙盒完全隔离。
    /// 配合 App 启动时的**幂等重建**（``UITestIsolation``），每次启动都是
    /// 全新环境：磁盘目录、SwiftData 数据库行、插件数据全部清空后重建。
    ///
    /// 于是「仓库为空」「仓库只有我造的那几首」都成为**确定性前提**，
    /// 不再依赖上一次运行的残留，也不受开发者本地环境影响。
    ///
    /// 隔离目录名由**用例类名**派生（而非随机）：结构固定，失败现场可寻址、
    /// 可复现。同一类的不同用例共享一个隔离目录，但每次启动都会重建，
    /// 因此用例之间仍然互不影响。
    ///
    /// ## 显隐覆盖
    ///
    /// `-UI.ContentViewVisible YES` 通过 UserDefaults 的**参数域**强制内容区可见。
    /// 参数域的优先级高于持久化域，因此整条 UI 测试链路对「内容区显隐」是
    /// 封闭的：任何用例收起过内容区都不会污染后续用例的启动状态。
    /// 需要验证「落盘偏好真正生效」的用例必须另起一个**不带该参数**的 App 实例
    /// （见 `CisumContentVisibilityUITests`）。
    ///
    /// - Important: `-UI.ContentViewVisible YES` **必须放在参数列表最前面**。
    ///   UserDefaults 的参数域在遇到第一个**不含 `=`** 的参数时就停止解析，
    ///   而 `YES` 正是这样的裸值——把它放在前面，它必定已被解析；放在后面，
    ///   它前面那些裸值参数（如 `--cisum-ui-testing-seed-audio Tone.wav` 的
    ///   `Tone.wav`）会截断解析，让覆盖**静默失效**。
    ///   静默失效的后果很隐蔽：内容区保持收起 → `cisum.kernel.ready` 不出现
    ///   → 报「主界面未组装」，看起来像启动超时，实际是显隐覆盖没生效。
    ///
    ///   子类追加参数时必须用 ``appendingLaunchArguments(_:)``（它把追加项放在
    ///   显隐覆盖参数**之后**），不要用 `+` 直接拼到最前面——那会让裸值参数
    ///   跑到显隐覆盖参数之前，把覆盖截断掉。
    ///
    /// ## 覆写约定（重要）
    ///
    /// **不要**整体覆写本属性。历史上 `CisumWelcomeUITests` 覆写成
    /// `["--cisum-ui-testing", "--cisum-ui-testing-reset-storage"]`，
    /// 连带丢掉了隔离参数——于是该用例既跑在真实沙盒里，又读到了真实
    /// `UserDefaults` 里被别的用例写坏的显隐偏好，测试结论因此依赖执行顺序。
    ///
    /// 正确做法是**只追加**需要的参数，且必须用 ``appendingLaunchArguments(_:)``：
    ///
    /// ```swift
    /// override var additionalLaunchArguments: [String] {
    ///     appendingLaunchArguments(["--cisum-ui-testing-reset-storage"])
    /// }
    /// ```
    ///

    ///
    /// 需要「落盘偏好真正生效」（不带显隐覆盖）时，用
    /// ``launchArgumentsWithoutVisibilityOverride`` 派生，而不是手写参数列表。
    ///
    /// - Important: 用 ``appendingLaunchArguments(_:)`` 追加，不要用 `+` 直接
    ///   拼接——显隐覆盖参数必须在列表最前面（见上文），拼接会让追加的裸值
    ///   参数跑到它之前，把覆盖截断掉。
    var additionalLaunchArguments: [String] {
        defaultLaunchArguments
    }

    /// 派生一份**不预设存储位置**的启动参数。
    ///
    /// `--cisum-ui-testing-storage-local` 会在 App 启动时直接写入存储位置，
    /// 于是「首启引导」不再需要——引导层不会出现。首启引导专项用例必须
    /// 在**保留隔离**的前提下去掉这个参数（而不是像历史上那样整体覆写
    /// 整个参数列表，那会连带丢掉隔离）。
    var launchArgumentsWithoutStoragePreset: [String] {
        defaultLaunchArguments.filter { $0 != "--cisum-ui-testing-storage-local" }
    }

    /// 把追加的参数并入启动参数（放在显隐覆盖参数**之后**）。
    ///
    /// 用它而不是 `+` 直接拼接，是为了守住两条约定：
    ///
    /// 1. **不手写参数列表**——手抄一次就可能漏掉隔离参数或显隐覆盖参数，
    ///    而漏掉不会有任何报错，只会让用例悄悄跑在错误的隔离环境里；
    /// 2. **不破坏参数顺序**——显隐覆盖参数必须在最前面（UserDefaults 参数域
    ///    遇裸值即止），追加项必须落在它之后。
    func appendingLaunchArguments(_ extra: [String]) -> [String] {
        defaultLaunchArguments + extra
    }

    /// 基类的默认启动参数（隔离 + 显隐覆盖）。
    ///
    /// 拆成独立属性，是为了让「派生无覆盖变体」与「子类追加参数」都不必
    /// 重抄参数列表——手抄就会漏，漏了就会让隔离失效。
    var defaultLaunchArguments: [String] {
        [
            "-UI.ContentViewVisible", "YES",
            "--cisum-ui-testing",
            "--cisum-ui-testing-storage-local",
            "--cisum-ui-testing-reset-scene",
            "--cisum-ui-testing-isolated-storage=\(Self.isolatedStorageName)",
        ]
    }

    /// 去掉显隐覆盖参数的启动参数变体。
    ///
    /// 用于「必须验证落盘偏好真正生效」的用例：显隐覆盖参数一旦在位，
    /// 启动参数就会盖过落盘值，落盘值永远不参与判定。
    ///
    /// **隔离参数必须保留**——去掉它等于让用例跑在真实沙盒与真实偏好上，
    /// 既污染开发者环境，又让结论依赖其它用例的残留。
    var launchArgumentsWithoutVisibilityOverride: [String] {
        defaultLaunchArguments.filter { $0 != "-UI.ContentViewVisible" && $0 != "YES" }
    }

    /// 本次启动的**隔离作用域**名。
    ///
    /// 隔离的磁盘目录与偏好 suite 都按这个名字派生，因此作用域是「一个
    /// 用例能看见哪些状态」的**唯一决定因素**。
    ///
    /// 默认按**用例类名**派生：同一类的用例共享同一份状态（失败现场可寻址、
    /// 可复现），不同类互不干扰。App 启动时会幂等重建磁盘目录，因此共享
    /// 不带来磁盘残留。
    ///
    /// 但**偏好**不会被幂等重建——同一类里的多个用例会互相影响落盘值。
    /// 需要「自己的状态不被同类的其它用例看到」的用例，必须覆写本属性
    /// 给出**专属作用域**。
    ///
    /// - Important: 覆写时要用**用例自己的名字**，不能用随机的值：随机会让
    ///   「上次失败的场景」这次不复现，只剩一句「它昨天挂过一次」。
    static var isolationScope: String {
        String(describing: self)
    }

    /// 本次启动使用的隔离数据根目录名。
    ///
    /// 由 ``isolationScope`` 派生：同一作用域的用例共享目录（便于失败现场
    /// 可复现），不同作用域互不干扰。App 启动时会幂等重建该目录，因此共享
    /// 不带来污染。
    static var isolatedStorageName: String {
        let sanitized = isolationScope
            .replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return sanitized.isEmpty ? "default" : sanitized
    }

    /// 真实 iCloud 容器是否可用。
    ///
    /// iCloud 容器需要设备**已登录 iCloud 账号**。没有账号（或容器被系统
    /// 禁用）时，容器路径根本不存在——这是真实的系统约束，任何实现都绕不过去。
    ///
    /// 因此 iCloud 专项用例必须显式判断并 `XCTSkip`，**绝不能**让它
    /// 「因为容器不存在而顺带通过」——那样这条用例在没登录 iCloud 的机器上
    /// 根本没测到任何东西，却和其它机器一样显示为绿色。
    ///
    /// 跨机一致性由这条约定保证：要么真的测了 iCloud 路径，要么**明确**
    /// 报告「本机未覆盖」，而不是混进全绿结果里。
    var isRealICloudContainerAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
            && FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
    }

    /// 要求真实 iCloud 容器可用，否则显式跳过。
    ///
    /// - Parameter reason: 跳过原因（会出现在测试报告中）。
    func requireRealICloudContainer(reason: String) throws {
        guard isRealICloudContainerAvailable else {
            throw XCTSkip(
                """
                \(reason) 需要真实 iCloud 容器，但当前设备未登录 iCloud 账号
                （或容器不可用）。本用例在未覆盖 iCloud 路径的机器上被显式跳过，
                而不是「因为容器不存在而顺带通过」——
                否则它会与其它机器一样显示为绿色，却什么都没测。
                """
            )
        }
    }

    /// 主容器元素：macOS 是名为 `Cisum` 的可调整窗口，iOS 是整个屏幕窗口。
    ///
    /// 跨平台布局回归统一用它作为「可见边界」，从而让同一份断言在两个平台上
    /// 复用，无需各自维护 `#if os(macOS)` 分支。
    var mainWindow: XCUIElement {
        #if os(macOS)
        app.windows["Cisum"]
        #else
        app.windows.firstMatch
        #endif
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += additionalLaunchArguments
        app.launch()
        waitForKernelReady()
    }

    func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func element(anyLabelOf labels: [String]) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label IN %@ OR value IN %@", labels, labels))
            .firstMatch
    }

    func element(labelBeginsWith prefixes: [String]) -> XCUIElement {
        let predicates = prefixes.map {
            NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", $0, $0)
        }
        return app.descendants(matching: .any)
            .matching(NSCompoundPredicate(orPredicateWithSubpredicates: predicates))
            .firstMatch
    }

    func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text))
            .firstMatch
    }

    func element(containingAny texts: [String]) -> XCUIElement {
        let predicates = texts.map {
            NSPredicate(format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@", $0, $0)
        }
        return app.descendants(matching: .any)
            .matching(NSCompoundPredicate(orPredicateWithSubpredicates: predicates))
            .firstMatch
    }

    func waitForKernelReady(timeout: TimeInterval = 20) {
        XCTAssertTrue(
            element(identifier: "cisum.kernel.ready").waitForExistence(timeout: timeout),
            "Cisum 未在 \(timeout)s 内完成主界面组装"
        )
        XCTAssertFalse(
            element(identifier: "cisum.kernel.startup-error").exists,
            "Cisum 显示了启动错误屏"
        )
    }

    /// 等待某个元素**持续不存在**。
    ///
    /// 与 `waitForExistence` 相反：用于「某状态不应该出现」的断言。
    /// 返回 true 表示在超时前元素始终没有出现。
    func waitForNonExistence(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists { return false }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return !element.exists
    }

    func switchScene(to labels: [String]) {
        #if os(macOS)
        let sceneID = labels.contains(where: { ["Music Library", "音乐仓库"].contains($0) })
            ? "music"
            : "audiobooks"
        let targetScene = element(identifier: "cisum.scene.\(sceneID)")
        if targetScene.waitForExistence(timeout: 1) { return }

        let switcher = element(identifier: "cisum.scene.switcher")
        XCTAssertTrue(switcher.waitForExistence(timeout: 10), "工具栏找不到场景切换器")
        switcher.click()

        // 场景选择器是弹出层：整条 UI 测试链路一起跑时，它的出现与可点击
        // 会比单独跑慢一些。分段等待 + 必要时重开，比一次性等待稳。
        let segment = element(identifier: "cisum.scene.option.\(sceneID)")
        if !segment.waitForExistence(timeout: 10) {
            // 第一次点击可能没打开弹出层（窗口刚拿到焦点）。重开一次再等。
            switcher.click()
            XCTAssertTrue(segment.waitForExistence(timeout: 10), "场景选择器中找不到目标场景：\(labels)")
        }
        segment.click()

        let enterButton = element(identifier: "cisum.scene.enter.\(sceneID)")
        if enterButton.waitForExistence(timeout: 10) {
            enterButton.click()
            XCTAssertTrue(targetScene.waitForExistence(timeout: 10), "点击「进入场景」后目标场景未出现：\(sceneID)")
        } else {
            XCTAssertTrue(targetScene.waitForExistence(timeout: 10), "找不到「进入场景」按钮，且目标场景未直接切换")
        }
        #endif
    }

    func ensureMusicScene() throws {
        #if os(macOS)
        switchScene(to: ["Music Library", "音乐仓库"])
        #else
        if !element(identifier: "cisum.scene.music").exists {
            throw XCTSkip("iOS 上无法通过 UI 切换场景，且当前不在音乐场景")
        }
        #endif
    }

    func ensureAudiobooksScene() throws {
        #if os(macOS)
        switchScene(to: ["Audiobooks", "有声书"])
        #else
        if !element(identifier: "cisum.scene.audiobooks").exists {
            throw XCTSkip("iOS 上无法通过 UI 切换场景，且当前不在有声书场景")
        }
        #endif
    }

    #if os(macOS)
    /// 通过系统文件选择器导入测试音频。
    ///
    /// 音乐仓库没有公开的自动化导入入口，只能驱动真实选择器。
    /// 注意：macOS 27+ 的跨进程选择器自动化不稳定，调用方应先按版本跳过。
    func importFixtureViaFilePicker(fixtureURL: URL) {
        let importButton = element(anyLabelOf: ["Add", "添加"])
        XCTAssertTrue(importButton.waitForExistence(timeout: 10), "音乐仓库没有音频导入入口")
        importButton.click()

        let panelService = XCUIApplication(bundleIdentifier: "com.apple.appkit.xpc.openAndSavePanelService")
        let servicePanel = panelService.windows.firstMatch
        let appPanel = app.dialogs.firstMatch
        let appSheet = app.sheets.firstMatch
        let servicePanelAppeared = servicePanel.waitForExistence(timeout: 5)
        let panelAppeared = servicePanelAppeared
            || appPanel.waitForExistence(timeout: 1)
            || appSheet.waitForExistence(timeout: 1)
        XCTAssertTrue(panelAppeared, "点击导入后系统文件选择器没有出现")
        let pickerApp: XCUIApplication = servicePanelAppeared ? panelService : app

        pickerApp.typeKey("g", modifierFlags: [.command, .shift])
        let goToFolderField = pickerApp.textFields["PathTextField"]
        XCTAssertTrue(goToFolderField.waitForExistence(timeout: 5), "文件选择器没有显示路径输入框")
        goToFolderField.click()
        goToFolderField.typeKey("a", modifierFlags: .command)
        let fixtureFolderPath = fixtureURL.deletingLastPathComponent().path
        goToFolderField.typeText(fixtureFolderPath)
        pickerApp.typeKey(.return, modifierFlags: [])
        pickerApp.typeKey(.return, modifierFlags: [])

        let name = fixtureURL.deletingPathExtension().lastPathComponent
        let fixtureRow = element(containing: String(name.prefix(18)))
        XCTAssertTrue(fixtureRow.waitForExistence(timeout: 10), "文件选择器未定位到测试音频: \(name)")
        fixtureRow.doubleClick()

        XCTAssertTrue(
            pickerApp.windows.firstMatch.waitForNonExistence(timeout: 15)
                || app.dialogs.firstMatch.waitForNonExistence(timeout: 1),
            "文件选择器关闭前未完成测试音频导入"
        )
    }

    /// 删除此前导入的测试音频，保持仓库干净。
    func deleteImportedFixtureIfPresent(fixtureName: String) {
        let track = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", fixtureName)).firstMatch
        guard track.exists else { return }

        track.rightClick()
        let deleteMenuItem = app.menuItems.matching(identifier: "trash").firstMatch
        XCTAssertTrue(deleteMenuItem.waitForExistence(timeout: 5), "曲目上下文菜单中没有删除命令")
        deleteMenuItem.click()

        let confirmDelete = app.buttons.matching(identifier: "Delete").firstMatch
            .exists
            ? app.buttons.matching(identifier: "Delete").firstMatch
            : app.buttons.matching(identifier: "删除").firstMatch
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), "删除确认没有出现")
        confirmDelete.click()
        XCTAssertTrue(track.waitForNonExistence(timeout: 15), "测试音频未从音乐仓库清理: \(fixtureName)")
    }

    /// macOS 27+ 的系统文件选择器无法稳定完成跨进程 UI 自动化导入。
    func skipIfFilePickerAutomationUnavailable() throws {
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 {
            throw XCTSkip("macOS 27 的系统文件选择器无法稳定完成跨进程 UI 自动化导入")
        }
    }
    #endif

    #if os(macOS)
    func assertElementFitsWindow(
        _ element: XCUIElement,
        window: XCUIElement,
        description: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.exists, "\(description)未渲染", file: file, line: line)
        XCTAssertGreaterThan(element.frame.width, 0, "\(description)没有有效宽度", file: file, line: line)
        XCTAssertGreaterThan(element.frame.height, 0, "\(description)没有有效高度", file: file, line: line)
        XCTAssertTrue(
            window.frame.insetBy(dx: -2, dy: -2).contains(element.frame),
            "\(description)超出主窗口：id=\(element.identifier), label=\(element.label), value=\(element.value ?? "nil"), element=\(element.frame), window=\(window.frame)",
            file: file,
            line: line
        )
    }

    func text(containing fragments: [String]) -> XCUIElement {
        let predicates = fragments.map {
            NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", $0, $0)
        }
        return app.staticTexts.matching(NSCompoundPredicate(orPredicateWithSubpredicates: predicates)).firstMatch
    }

    /// 快照窗口顶部工具栏中的全部可交互控件。
    ///
    /// 供「某状态下工具栏必须完全干净」这类回归使用：既要覆盖
    /// NSToolbar 上的独立 item，也要覆盖 SwiftUI `.toolbar` 贡献进去的
    /// `ToolbarItem` / `ToolbarItemGroup`（后者在 AX 树里同样是 toolbar
    /// 的后代，因此统一走 descendants 查询）。
    ///
    /// 工具栏整体不存在等价于「没有任何控件」，返回空数组而非判失败：
    /// 隐藏整条工具栏是正确的修复形态，不应因此报错。
    func interactiveToolbarControls(in window: XCUIElement) -> [String] {
        let toolbar = window.toolbars.firstMatch
        guard toolbar.exists else { return [] }

        let queries: [(String, XCUIElementQuery)] = [
            ("button", toolbar.descendants(matching: .button)),
            ("popUpButton", toolbar.descendants(matching: .popUpButton)),
            ("menuButton", toolbar.descendants(matching: .menuButton)),
            ("menu", toolbar.descendants(matching: .menu)),
            ("menuItem", toolbar.descendants(matching: .menuItem)),
            ("comboBox", toolbar.descendants(matching: .comboBox)),
            ("checkBox", toolbar.descendants(matching: .checkBox)),
            ("toggle", toolbar.descendants(matching: .toggle)),
        ]

        var controls: [String] = []
        for (kind, query) in queries {
            for index in 0..<query.count {
                let control = query.element(boundBy: index)
                controls.append(
                    "\(kind) id=\(control.identifier) label=\"\(control.label)\" frame=\(control.frame)"
                )
            }
        }
        return controls
    }
    #endif

    #if !os(macOS)
    /// iOS 版「元素必须完整落在可见屏幕内」断言。
    ///
    /// 与 macOS 的 `assertElementFitsWindow` 对称：iOS 没有可调整大小的窗口，
    /// 唯一边界就是 `app.windows.firstMatch`（整屏）。用于替代原先被
    /// `#else throw XCTSkip("仅 macOS 支持")` 短路的响应式布局回归。
    ///
    /// - Parameters:
    ///   - element: 被检查的元素。
    ///   - description: 断言失败信息中使用的元素描述。
    ///   - slop: 允许的容差（pt）。用于吸收异步布局与安全区计算的取整误差。
    func assertElementFitsScreen(
        _ element: XCUIElement,
        description: String,
        slop: CGFloat = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.exists, "\(description)未渲染", file: file, line: line)
        XCTAssertGreaterThan(element.frame.width, 0, "\(description)没有有效宽度", file: file, line: line)
        XCTAssertGreaterThan(element.frame.height, 0, "\(description)没有有效高度", file: file, line: line)

        let screen = app.windows.firstMatch.frame
        XCTAssertTrue(
            screen.insetBy(dx: -slop, dy: -slop).contains(element.frame),
            "\(description)超出屏幕：id=\(element.identifier), label=\(element.label), value=\(element.value ?? "nil"), element=\(element.frame), screen=\(screen)",
            file: file,
            line: line
        )
    }

    /// iOS 触控热区回归：按钮必须满足 HIG 最小 44×44pt。
    ///
    /// macOS 的对应断言写在 `CisumPlayerUITests` 内且随该用例一起跳过，
    /// 这里抽成基类能力，供 iOS 侧直接复用。
    func assertButtonHasMinimumTapTarget(
        _ button: XCUIElement,
        description: String,
        minimum: CGFloat = 44,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(button.exists, "\(description)未渲染", file: file, line: line)
        XCTAssertGreaterThanOrEqual(
            button.frame.width, minimum,
            "\(description)触控热区宽度低于 \(Int(minimum))pt：frame=\(button.frame)",
            file: file, line: line
        )
        XCTAssertGreaterThanOrEqual(
            button.frame.height, minimum,
            "\(description)触控热区高度低于 \(Int(minimum))pt：frame=\(button.frame)",
            file: file, line: line
        )
    }
    #endif

    func openSettingsWindowViaMenu() {
        #if os(macOS)
        XCTAssertTrue(app.windows["Cisum"].waitForExistence(timeout: 10))

        let appMenu = app.menuBars.menuBarItems["Cisum"]
        XCTAssertTrue(appMenu.waitForExistence(timeout: 5), "Cisum 应用菜单不可用")
        appMenu.click()

        let settingsCommand = app.menuItems["Settings…"]
        XCTAssertTrue(settingsCommand.waitForExistence(timeout: 5), "Settings… 命令不可用")
        settingsCommand.click()
        #endif
    }

    func closeSettingsWindow() {
        #if os(macOS)
        let settingsWindow = app.windows.matching(identifier: "cisum.settings").firstMatch
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 10), "设置窗口未出现，无法关闭")

        let closeButtonCandidates = [
            settingsWindow.buttons.matching(identifier: "_XCUI:CloseWindow").firstMatch,
            settingsWindow.buttons.matching(identifier: "AXCloseButton").firstMatch,
            settingsWindow.buttons["Close"],
            settingsWindow.buttons["关闭"],
        ]
        guard let closeButton = closeButtonCandidates.first(where: { $0.waitForExistence(timeout: 2) }) else {
            XCTFail("设置窗口没有可用的关闭按钮：\n\(settingsWindow.debugDescription)")
            return
        }

        closeButton.click()
        XCTAssertTrue(settingsWindow.waitForNonExistence(timeout: 10), "设置窗口关闭后仍然存在")
        XCTAssertTrue(app.windows["Cisum"].waitForExistence(timeout: 10), "关闭设置窗口后主窗口没有恢复")
        #endif
    }
}
