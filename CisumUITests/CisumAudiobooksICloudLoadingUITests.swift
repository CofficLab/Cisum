import XCTest

/// iCloud 存储配置下，场景切换时"正在读取有声书仓库"状态的回归测试。
///
/// ## 为什么要有这一组用例
///
/// 已有的 `CisumAudiobooksLoadingUITests` 走的是 **本地存储** 分支
/// （`--cisum-ui-testing-storage-local`）。而真实用户配置里
/// `StorageLocation = icloud`，走的是完全不同的目录监控实现：
///
/// - 本地：`LocalDirectoryMonitor`（DispatchSource + 立即首次扫描）
/// - iCloud：`ICloudDirectoryMonitor`（NSMetadataQuery + 后台队列首次扫描）
///
/// 「正在读取有声书仓库」一直不消失，正对应 `BookRepo.waitForInitialSync()`
/// 迟迟不返回，因此这条路径必须被用例单独钉住。
///
/// ## 复现路径
///
/// 用户报告的是「**启动时是音乐模式**，切到有声书后一直显示正在读取」。
/// 用例先用 `ensureMusicScene()` 把场景拨回音乐模式（场景是持久化的，
/// 上一次运行留下的状态不能决定本次走哪条路径），再切到有声书场景，
/// 覆盖的正是「音乐 → 有声书」这条路径。
final class CisumAudiobooksICloudLoadingUITests: CisumUITestBase {

    /// 覆盖基类的启动参数：
    /// - `--cisum-ui-testing-storage-icloud`：用 iCloud 存储，与真实配置一致；
    /// - `--cisum-ui-testing-reset-scene`：忽略上次持久化的场景，
    ///   固定从音乐库启动（场景是持久化的，否则本次启动落在哪个场景
    ///   取决于上一次运行留下的状态，用例就无法稳定复现用户报告的路径）。
    override var additionalLaunchArguments: [String] {
        [
            "--cisum-ui-testing",
            "--cisum-ui-testing-storage-icloud", "--cisum-ui-testing-reset-scene",
            "-UI.ContentViewVisible", "YES",
        ]
    }

    /// iCloud 容器解析（`ubiquityIdentityToken` /
    /// `url(forUbiquityContainerIdentifier:)`）会在启动阶段阻塞，
    /// 基类 20s 的内核就绪等待在这里不够用。
    override func waitForKernelReady(timeout: TimeInterval = 20) {
        super.waitForKernelReady(timeout: 90)
    }

    /// "正在读取有声书仓库" 加载态。
    private var loadingIndicator: XCUIElement {
        element(anyLabelOf: ["Reading book repository", "正在读取有声书仓库"])
    }

    /// 有声书内容区是否已经呈现真实内容（表头统计 / 书卡 / 空状态 / 不可用提示）。
    private var contentIsRendered: Bool {
        let header = element(labelBeginsWith: ["Total", "共"])
        let bookTile = element(labelBeginsWith: ["Select ", "选择"])
        let emptyState = element(containingAny: [
            "Drop audiobook folders here to add them",
            "将有声书文件夹拖到这里可添加",
            "Audiobook repository is empty",
            "有声书仓库为空",
            "Repository is empty",
            "仓库为空",
        ]).exists
        let unavailable = element(identifier: "cisum.scene.audiobooks.unavailable").exists
        return header.exists || bookTile.exists || emptyState || unavailable
    }

    /// 复现步骤：音乐模式 → 切换到有声书模式。
    ///
    /// 预期：有声书场景必须在有限时间内结束"读取中"状态并呈现内容。
    func testSwitchingToAudiobooksUnderICloudStorageDoesNotStall() throws {
        #if os(macOS)
        // 前提：处于音乐模式（否则这条用例测的是另一条路径）。
        try ensureMusicScene()
        XCTAssertTrue(
            element(identifier: "cisum.scene.music").waitForExistence(timeout: 30),
            "未能处于音乐场景，无法复现「音乐 → 有声书」路径"
        )

        try ensureAudiobooksScene()
        XCTAssertTrue(
            element(identifier: "cisum.scene.audiobooks").waitForExistence(timeout: 15),
            "有声书场景未出现"
        )

        // 加载态必须自行结束。给足 30s：iCloud 首次扫描会走一次真实文件系统
        // 枚举，超过这个时间就说明流程已经卡死（而不是"慢"）。
        let timeout: TimeInterval = 30
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if !loadingIndicator.exists { break }
            Thread.sleep(forTimeInterval: 0.5)
        }

        XCTAssertFalse(
            loadingIndicator.exists,
            """
            有声书仓库在 \(Int(timeout))s 后仍显示"正在读取有声书仓库"。
            这意味着加载流程没有走到终点——
            要么 BookRepo.waitForInitialSync() 一直没返回，
            要么加载请求在视图生命周期切换时被取消且没有重新触发。
            """
        )

        XCTAssertTrue(
            contentIsRendered,
            "有声书场景没有呈现任何内容（既无表头统计，也无书卡、空状态或不可用提示）"
        )
        #else
        throw XCTSkip("场景切换测试仅 macOS 支持")
        #endif
    }
}
