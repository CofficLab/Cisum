import Foundation
import XCTest

/// iCloud 文件自动下载的 UI 行为。
///
/// XCUITest 无法在 CI 中真实制造「占位未下载」的 iCloud 文件（需要机器登录
/// iCloud Drive，且 `brctl` 驱逐后不能被自动同步回来）。因此通过启动参数
/// 让 App 在**启动阶段**进入脚本化的下载态：
/// - `--cisum-ui-testing-icloud-download=<success|timeout|offline>` 注入测试网关
///   （`MagicKit.ICloudDownloadControl`）；
/// - `--cisum-ui-testing-playback-file <name>` 让 PluginPlayBack 在启动恢复时
///   直接播放 seed 文件（音频经 `--cisum-ui-testing-seed-audio` 在 App 沙盒创建）。
///
/// 每种下载模式一个测试类：类内只使用基类 setUp 的一次启动，不使用
/// terminate + relaunch（该模式在持续集成环境中表现出启动不可靠）。
///
/// ⚠️ 已知限制：默认窗口（400x600）下 Hero 下载覆盖层
/// （cisum.player.download.overlay）不渲染（布局条件要求控制区高度 > 450pt），
/// 对它的「不存在」断言没有判别力，改由「按钮禁用」覆盖。
class CisumICloudTestBase: CisumUITestBase {
    let seededAudioName = "Cisum-ICloud-Download-Test.wav"

    /// 由子类指定的下载模式（success / timeout / offline）。
    var icloudMode: String { "timeout" }

    /// iOS 模拟器无系统文件选择器，iCloud 下载注入依赖 macOS 的系统选择器
    /// 入口或真机账户。CI 模拟器无法复现「占位未下载」状态，本组测试在 iOS
    /// 上显式跳过。macOS 走原始 system file picker 路径。
    override func setUpWithError() throws {
        #if !os(macOS)
        throw XCTSkip("iCloud 下载 UI 行为依赖系统文件选择器，暂不在 iOS UI 测试中覆盖")
        #else
        try super.setUpWithError()
        #endif
    }

    override var additionalLaunchArguments: [String] {
        super.additionalLaunchArguments
            + [
                "--cisum-ui-testing-icloud-download=\(icloudMode)",
                // 必须同时**播种**被播放的文件：`--cisum-ui-testing-playback-file`
                // 只是把路径写进播放槽位，App 启动后会去恢复播放它。若文件不存在，
                // 恢复流程卡住，主窗口根本不会出现（表现为「主界面未组装」）。
                "--cisum-ui-testing-seed-audio", seededAudioName,
                "--cisum-ui-testing-playback-file", seededAudioName,
            ]
    }

    var pauseButton: XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@", "pause.fill")).firstMatch
    }

    var playButton: XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@", "play.fill")).firstMatch
    }

    func seededTrack() -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", seededAudioName)).firstMatch
    }

    /// 确认 seed 曲目已入库（启动恢复播放的前置条件）。
    @discardableResult
    func waitForSeededTrackReady(file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard seededTrack().waitForExistence(timeout: 20) else {
            XCTFail("seed 音频未出现在音乐仓库", file: file, line: line)
            return false
        }
        return true
    }
}

// MARK: - timeout 模式（8s 下载等待窗口）

/// timeout 模式：启动恢复播放 → 进入 8s 下载等待 → 超时失败。
final class CisumICloudDownloadTimeoutUITests: CisumICloudTestBase {
    override var icloudMode: String { "timeout" }

    /// 标题下方不得出现重复的下载百分比行。
    ///
    /// 该行曾拼成「0% 正在下载 0%」——外层前缀与引擎 `localizedStateText()`
    /// 自带的百分比各占一个。下载进度改由封面区大圆环独占呈现，故此处断言其不存在。
    func testNoDuplicateDownloadStatusLineBelowTitle() throws {
        guard waitForSeededTrackReady() else { return }

        let statusLine = element(identifier: "cisum.player.download.status")

        // 给下载态一点时间出现：若该行仍被渲染，此处应能捕获到。
        _ = element(identifier: "cisum.player.title").waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 2)

        XCTAssertFalse(
            statusLine.exists,
            "标题下方不应再渲染下载状态行 cisum.player.download.status（会显示成重复百分比）"
        )
    }

    /// 下载/加载期间播放按钮必须禁用，避免用户点击后静默无响应。
    func testPlayButtonDisabledWhileDownloading() throws {
        guard waitForSeededTrackReady() else { return }

        var sawDisabled = false
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if playButton.exists, !playButton.isEnabled {
                sawDisabled = true
                break
            }
            Thread.sleep(forTimeInterval: 0.3)
        }

        XCTAssertTrue(
            sawDisabled,
            "iCloud 下载等待期间播放按钮应被禁用（当前始终 enabled，点击后静默无响应）"
        )
    }

    /// 超时后不得进入播放态、不得卡死，播放器控件保持可用。
    func testTimeoutDoesNotEnterPlayingOrHang() throws {
        guard waitForSeededTrackReady() else { return }

        // 下载等待（8s）及结束后都不应进入播放态；用 identifier 判定，避免本地化文案差异。
        XCTAssertFalse(
            pauseButton.waitForExistence(timeout: 12),
            "iCloud 下载超时时不应进入播放态"
        )
        XCTAssertTrue(
            playButton.waitForExistence(timeout: 5),
            "下载超时后播放器控件消失（App 卡死或崩溃）"
        )
        XCTAssertFalse(
            element(identifier: "cisum.kernel.startup-error").exists,
            "下载超时后内核出现启动错误"
        )
    }
}

// MARK: - offline 模式（立即失败）

/// offline 模式：启动恢复播放 → 发起下载立即失败。
final class CisumICloudDownloadOfflineUITests: CisumICloudTestBase {
    override var icloudMode: String { "offline" }

    /// 离线失败不得进入播放态、App 不得卡死。
    func testOfflineDoesNotEnterPlayingOrHang() throws {
        guard waitForSeededTrackReady() else { return }

        XCTAssertFalse(
            pauseButton.waitForExistence(timeout: 8),
            "离线时不应进入播放态"
        )
        XCTAssertTrue(
            playButton.waitForExistence(timeout: 5),
            "离线失败后播放器控件消失（App 卡死或崩溃）"
        )
        XCTAssertFalse(
            element(identifier: "cisum.kernel.startup-error").exists,
            "离线失败后内核出现启动错误"
        )
    }
}

// MARK: - success 模式（快速完成下载）

/// success 模式：下载快速完成后 App 保持健康。
final class CisumICloudDownloadSuccessUITests: CisumICloudTestBase {
    override var icloudMode: String { "success" }

    /// success 模式下内核与播放器控件保持可用。
    func testAppHealthyAfterDownload() throws {
        guard waitForSeededTrackReady() else { return }

        XCTAssertTrue(
            playButton.waitForExistence(timeout: 10),
            "success 模式下播放器控件不可用"
        )
        XCTAssertTrue(
            element(identifier: "cisum.scene.music").exists,
            "success 模式下音乐仓库场景丢失"
        )
        XCTAssertFalse(
            element(identifier: "cisum.kernel.startup-error").exists,
            "success 模式下内核出现启动错误"
        )
    }
}

// MARK: - 列表呈现（无 icloud 参数）

/// 音乐库列表：seed 出的曲目必须出现，并带标题标识。
final class CisumICloudLibraryUITests: CisumUITestBase {
    private let seededAudioName = "Cisum-ICloud-Download-Test.wav"

    override var additionalLaunchArguments: [String] {
        super.additionalLaunchArguments + ["--cisum-ui-testing-seed-audio", seededAudioName]
    }

    func testSeededTrackAppearsInLibrary() throws {
        try ensureMusicScene()

        let track = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", seededAudioName)).firstMatch
        XCTAssertTrue(track.waitForExistence(timeout: 20), "seed 音频未出现在音乐仓库")

        let title = element(identifier: "cisum.audio-library.item.title")
        XCTAssertTrue(
            title.waitForExistence(timeout: 10),
            "音乐库列表项缺少标题标识 cisum.audio-library.item.title"
        )
    }
}

// MARK: - 播放按钮下载进度环

/// 播放按钮的下载进度环：用注入的固定进度值验证「圆环 + 中心百分比」。
///
/// 进度来源说明：真实进度由 `GlobalDownloadMonitor` 读 iCloud 资源键，在没有
/// dataless 占位文件的机器上恒为 0，UI 测试无法断言非零百分比。因此新增
/// `--cisum-ui-testing-download-progress=<0...1>`，在真实 App 进程里把
/// `getDownloadProgressSnapshot` 覆写成确定值（见 `ICloudDownloadControl`）。
///
/// 配合 `timeout` 模式使用：下载永不完成，下载态可稳定停留 8s，足够断言。
final class CisumPlayerDownloadRingUITests: CisumICloudTestBase {
    private let injectedProgress = 0.42

    override var icloudMode: String { "timeout" }

    override var additionalLaunchArguments: [String] {
        super.additionalLaunchArguments
            + ["--cisum-ui-testing-download-progress=\(injectedProgress)"]
    }

    /// 下载期间播放按钮位置应出现进度环，且无障碍值等于注入的百分比。
    func testPlayButtonShowsDownloadRingWithInjectedProgress() throws {
        guard waitForSeededTrackReady() else { return }

        let ring = element(identifier: "cisum.player.button.download.progress")
        XCTAssertTrue(
            ring.waitForExistence(timeout: 10),
            "下载期间播放按钮位置没有出现进度环 cisum.player.button.download.progress"
        )

        guard ring.exists else { return }

        // accessibilityValue 承载中心文字的百分比。
        let value = ring.value as? String ?? ""
        XCTAssertEqual(
            value,
            "\(Int(injectedProgress * 100))%",
            "进度环显示的百分比与注入值不符：期望 \(Int(injectedProgress * 100))%，实际 \(value)"
        )
    }

    /// 进度环不得挤压或溢出窗口——按钮尺寸偏小时中间文字最容易越界。
    func testDownloadRingStaysInsideWindow() throws {
        #if os(macOS)
        guard waitForSeededTrackReady() else { return }

        let ring = element(identifier: "cisum.player.button.download.progress")
        guard ring.waitForExistence(timeout: 10) else {
            XCTFail("下载期间没有出现进度环，无法验证其布局")
            return
        }

        let window = app.windows["Cisum"].firstMatch
        guard window.waitForExistence(timeout: 5) else {
            XCTFail("找不到主窗口，无法验证进度环布局")
            return
        }

        assertElementFitsWindow(ring, window: window, description: "播放按钮下载进度环")
        #endif
    }

    /// 非下载态不得出现进度环：否则会与播放/暂停图标并存。
    func testNoDownloadRingWhenNotDownloading() throws {
        // success 模式：下载很快完成，App 进入稳定播放态。
        let healthyApp = XCUIApplication()
        healthyApp.launchArguments += [
            "--cisum-ui-testing",
            "--cisum-ui-testing-storage-local",
            "-UI.ContentViewVisible", "YES",
            "--cisum-ui-testing-seed-audio", seededAudioName,
            "--cisum-ui-testing-icloud-download=success",
        ]
        healthyApp.launch()
        XCTAssertTrue(
            element(identifier: "cisum.kernel.ready").waitForExistence(timeout: 20),
            "success 模式下 App 未完成启动"
        )

        let ring = healthyApp.descendants(matching: .any)
            .matching(identifier: "cisum.player.button.download.progress")
            .firstMatch
        XCTAssertFalse(
            ring.exists,
            "非下载态不应出现进度环（当前与播放图标并存）"
        )

        healthyApp.terminate()
    }
}
