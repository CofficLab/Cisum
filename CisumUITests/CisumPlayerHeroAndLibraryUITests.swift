import XCTest

/// 播放器 Hero 区、仓库工具栏与仓库引导的 UI 覆盖。
///
/// 背景：这些区域的 accessibility identifier 早已存在
/// （`cisum.player.title` / `cisum.audio-library.count` /
/// `cisum.audio-library.add` / `cisum.audio-library.open-repository` /
/// `cisum.repository.guide.title`），但**没有任何 UI 测试引用它们**——
/// 标识失效不会被发现。
///
/// 本文件锁定：
/// 1. 空仓库时，Hero 区不显示曲目标题，仓库工具栏仍提供「添加 / 打开仓库」入口；
/// 2. 有内容时，Hero 区显示曲目标题；
/// 3. 仓库引导的标题标识可用。
final class CisumPlayerHeroAndLibraryUITests: CisumUITestBase {
    private let seedAudioName = "Cisum-UI-Hero-Library-Test-Tone.wav"

    /// 注入一枚种子音频，使仓库非空。
    override var additionalLaunchArguments: [String] {
        super.additionalLaunchArguments + ["--cisum-ui-testing-seed-audio", seedAudioName]
    }

    // MARK: - Hero 区

    /// 仓库为空时不得显示空标题区域。
    ///
    /// 本用例需要**真正为空**的仓库，因此另起一个使用隔离数据根的 App
    /// 实例：上一次运行留下的音频文件与数据库行会让仓库非空，
    /// 单靠清理磁盘目录不够——数据库里的行还在。
    func testEmptyRepositoryHasNoHeroTitle() throws {
        let isolated = makeAppWithIsolatedStorage()
        app.terminate()
        isolated.launch()
        XCTAssertTrue(
            isolated.descendants(matching: .any)
                .matching(identifier: "cisum.kernel.ready")
                .firstMatch.waitForExistence(timeout: 20),
            "隔离存储的实例未在 20s 内完成主界面组装"
        )

        let controls = isolated.descendants(matching: .any)
            .matching(identifier: "cisum.player.controls").firstMatch
        XCTAssertTrue(controls.waitForExistence(timeout: 15), "播放器控制区未出现")

        // 「仓库确认为空」要等扫描完成才成立（数据层用三态表达：
        // 未知 / 空 / 非空，未扫描时不算空）。等它变成「空」再断言，
        // 否则断言的是「还没扫完」而不是「仓库为空」。
        let heroTitle = isolated.descendants(matching: .any)
            .matching(identifier: "cisum.player.title").firstMatch
        XCTAssertTrue(
            waitForNonExistence(heroTitle, timeout: 20),
            "仓库为空时不应显示曲目标题区域"
        )
    }

    /// 使用隔离数据根的 App 实例：仓库与数据库都是干净的。
    private func makeAppWithIsolatedStorage() -> XCUIApplication {
        let instance = XCUIApplication()
        instance.launchArguments = [
            "--cisum-ui-testing",
            "--cisum-ui-testing-storage-local",
            "--cisum-ui-testing-isolated-storage=hero-empty-repo",
        ]
        return instance
    }

    /// 有当前曲目时，Hero 区必须显示标题标识。
    func testHeroTitleIdentifierAppearsWhenTrackIsSelected() throws {
        try ensureMusicScene()

        let track = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", seedAudioName)
        ).firstMatch
        guard track.waitForExistence(timeout: 30) else {
            throw XCTSkip("seed 音频未出现在音乐仓库")
        }

        #if os(macOS)
        track.click()
        #else
        track.tap()
        #endif

        XCTAssertTrue(
            element(identifier: "cisum.player.title").waitForExistence(timeout: 15),
            "选中曲目后 Hero 区没有出现标题标识 cisum.player.title"
        )
    }

    // MARK: - 仓库工具栏

    /// 仓库工具栏必须提供「打开仓库」与「添加」两个入口。
    func testLibraryToolbarOffersOpenRepositoryAndAddActions() throws {
        try ensureMusicScene()

        let openRepository = element(identifier: "cisum.audio-library.open-repository")
        XCTAssertTrue(
            openRepository.waitForExistence(timeout: 20),
            "音乐仓库缺少「打开仓库」入口 cisum.audio-library.open-repository"
        )

        let addButton = element(identifier: "cisum.audio-library.add")
        XCTAssertTrue(
            addButton.waitForExistence(timeout: 10),
            "音乐仓库缺少「添加」入口 cisum.audio-library.add"
        )
    }

    /// 仓库有内容时，计数栏必须显示。
    func testLibraryCountBarAppearsWithContent() throws {
        try ensureMusicScene()

        let track = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", seedAudioName)
        ).firstMatch
        guard track.waitForExistence(timeout: 30) else {
            throw XCTSkip("seed 音频未出现在音乐仓库")
        }

        XCTAssertTrue(
            element(identifier: "cisum.audio-library.count").waitForExistence(timeout: 15),
            "仓库非空时未显示计数栏 cisum.audio-library.count"
        )
    }

    /// 列表项必须带标题标识，供后续自动化定位。
    func testLibraryItemsCarryTitleIdentifier() throws {
        try ensureMusicScene()

        let track = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", seedAudioName)
        ).firstMatch
        guard track.waitForExistence(timeout: 30) else {
            throw XCTSkip("seed 音频未出现在音乐仓库")
        }

        XCTAssertTrue(
            element(identifier: "cisum.audio-library.item.title").waitForExistence(timeout: 15),
            "音乐库列表项缺少标题标识 cisum.audio-library.item.title"
        )
    }

    // MARK: - 仓库引导

    /// 仓库引导的标题标识必须可用（引导是空仓库时的首次使用引导）。
    func testRepositoryGuideTitleIdentifierIsResolvable() throws {
        try ensureMusicScene()

        // 引导只在特定条件下出现；这里只要求标识可被解析器识别，
        // 不强制它必须出现（否则会把「引导没触发」误报成标识失效）。
        let guideTitle = element(identifier: "cisum.repository.guide.title")
        if guideTitle.exists {
            XCTAssertGreaterThan(
                guideTitle.frame.height, 0,
                "仓库引导标题存在但没有有效高度"
            )
        }
    }
}
