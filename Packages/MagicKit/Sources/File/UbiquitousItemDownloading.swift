import Foundation

// MARK: - Error

/// iCloud 下载流程的可识别错误。
///
/// 播放层据此把「iCloud 没下下来」与「网络错误」区分开，向用户展示不同的
/// 文案与恢复建议，而不是统统落到 `.networkError`。
public enum ICloudDownloadError: Error, Equatable {
    /// iCloud 不可用（未登录、离线、容器不可达）。
    case unavailable
    /// 请求下载失败（网络中断、权限被拒等）。
    case requestFailed(String)
    /// 在超时时间内内容始终没有落到本地磁盘。
    case timedOut(fileName: String)
    /// 调用方取消（切歌、任务取消）。
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "iCloud Drive is unavailable"
        case let .requestFailed(message):
            return "Failed to start iCloud download: \(message)"
        case let .timedOut(fileName):
            return "Timed out waiting for iCloud file to download: \(fileName)"
        case .cancelled:
            return "iCloud download was cancelled"
        }
    }

    /// 调用方是否应把该错误呈现为「iCloud 下载失败」而非普通播放失败。
    public var isICloudDownloadFailure: Bool { true }
}

// MARK: - Gateway

/// iCloud 下载能力的抽象网关。
///
/// 生产实现 `FileManagerUbiquitousItemDownloader` 直接调用 FileManager；
/// 测试替身 `StubUbiquitousItemDownloader` 可以脚本化成功 / 超时 / 离线，
/// 使播放状态机无需真实 iCloud 账号即可被完整验证。
public protocol UbiquitousItemDownloading: AnyObject, Sendable {
    /// 该 URL 是否位于 iCloud Documents 容器中。
    func isICloudBacked(_ url: URL) -> Bool

    /// 该 URL 的内容是否已经落到本地磁盘（可被读取）。
    func hasLocalContent(_ url: URL) -> Bool

    /// 发起下载。对已下载 / 下载中的项目必须幂等。
    func startDownload(_ url: URL) throws

    /// 0...1 的下载进度；无法判定时返回 0。
    func downloadProgress(_ url: URL) -> Double
}

// MARK: - Production

/// 生产实现：直接使用 FileManager 的 ubiquitous item 能力。
public final class FileManagerUbiquitousItemDownloader: UbiquitousItemDownloading, @unchecked Sendable {
    public init() {}

    public func isICloudBacked(_ url: URL) -> Bool {
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents") else {
            return false
        }

        return URLDirectoryContainmentPolicy.contains(url.path, inDirectory: container.path)
    }

    public func hasLocalContent(_ url: URL) -> Bool {
        url.magicKitHasLocalContent()
    }

    public func startDownload(_ url: URL) throws {
        try FileManager.default.startDownloadingUbiquitousItem(at: url)
    }

    public func downloadProgress(_ url: URL) -> Double {
        url.getDownloadProgressSnapshot(verbose: false)
    }
}

// MARK: - Stub

/// 测试替身：按脚本模拟 iCloud 下载结果。
///
/// UI 测试无法在 CI 中真实制造 dataless 文件，用它把播放链路推进到
/// 「下载中 / 下载失败」这些 UI 测试需要的状态。
public final class StubUbiquitousItemDownloader: UbiquitousItemDownloading, @unchecked Sendable {
    public enum Behavior: Equatable, Sendable {
        /// 已在本地，不触发下载。
        case alreadyLocal
        /// 需要 N 次轮询后内容才落到本地，期间进度线性上升。
        case succeeds(afterPolls: Int)
        /// 内容永远不会落地，最终表现为超时。
        case neverCompletes
        /// `startDownload` 直接失败（离线 / 无权限）。
        case startFails(message: String)
    }

    public let behavior: Behavior
    private let lock = NSLock()
    private var pollCounts: [URL: Int] = [:]
    private var startCallCount = 0

    public init(behavior: Behavior) {
        self.behavior = behavior
    }

    /// 被发起下载的次数，用于断言「重复请求是否被去重」。
    public var startDownloadCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return startCallCount
    }

    public func isICloudBacked(_ url: URL) -> Bool { true }

    public func hasLocalContent(_ url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        switch behavior {
        case .alreadyLocal:
            return true
        case let .succeeds(afterPolls):
            let count = pollCounts[url, default: 0]
            pollCounts[url] = count + 1
            return count >= afterPolls
        case .neverCompletes, .startFails:
            return false
        }
    }

    public func startDownload(_ url: URL) throws {
        lock.lock()
        startCallCount += 1
        lock.unlock()

        if case let .startFails(message) = behavior {
            throw ICloudDownloadError.requestFailed(message)
        }
    }

    public func downloadProgress(_ url: URL) -> Double {
        switch behavior {
        case .alreadyLocal:
            return 1
        case let .succeeds(afterPolls):
            guard afterPolls > 0 else { return 1 }
            lock.lock()
            let count = pollCounts[url, default: 0]
            lock.unlock()
            return min(Double(count) / Double(afterPolls), 1)
        case .neverCompletes, .startFails:
            return 0
        }
    }
}

// MARK: - Control

/// 进程级下载网关与超时策略的覆写入口。
///
/// 单元测试直接调用 `override(_:)` 注入替身；UI 测试通过启动参数
/// `--cisum-ui-testing-icloud-download=<success|timeout|offline>` 由
/// `bootstrapFromLaunchArguments()` 自动安装，使真实 App 进程也能进入
/// 可断言的下载态，而无需真实 iCloud 账号。
public final class ICloudDownloadControl: @unchecked Sendable {
    public static let shared = ICloudDownloadControl()

    /// UI 测试使用的启动参数键。
    public static let launchArgumentKey = "--cisum-ui-testing-icloud-download"

    /// UI 测试注入固定下载进度的启动参数键，形如
    /// `--cisum-ui-testing-download-progress=0.42`。
    public static let progressLaunchArgumentKey = "--cisum-ui-testing-download-progress"

    private let lock = NSLock()
    private var downloaderOverride: UbiquitousItemDownloading?
    private var timeoutOverride: TimeInterval?
    private var progressOverride: Double?
    private let production = FileManagerUbiquitousItemDownloader()

    private init() {}

    /// 当前生效的网关：测试注入优先，否则为生产实现。
    public var downloader: UbiquitousItemDownloading {
        lock.lock()
        defer { lock.unlock() }
        return downloaderOverride ?? production
    }

    /// 注入测试网关。传 nil 恢复生产实现。
    public func override(_ downloader: UbiquitousItemDownloading?) {
        lock.lock()
        downloaderOverride = downloader
        lock.unlock()
    }

    /// 覆写 `ensureLocalAvailability` 的默认超时，用于让 UI 测试快速走到超时分支。
    public func overrideTimeout(_ timeout: TimeInterval?) {
        lock.lock()
        timeoutOverride = timeout
        lock.unlock()
    }

    /// 生效的超时：优先使用覆写值。
    public var effectiveTimeout: TimeInterval? {
        lock.lock()
        defer { lock.unlock() }
        return timeoutOverride
    }

    /// 覆写下载进度快照，范围 0...1；nil 表示不覆写（使用真实资源键）。
    ///
    /// 存在的理由：`GlobalDownloadMonitor` 的进度来自 `NSMetadataQuery`，
    /// 它**绕过** `downloader` 网关直接读资源键，因此仅注入 `StubUbiquitousItemDownloader`
    /// 能把播放态推进到 `.downloading`，却无法让进度离开 0 —— UI 测试因此
    /// 断言不了任何非零百分比。此覆写让真实 App 进程能呈现确定的进度值。
    public func overrideProgress(_ progress: Double?) {
        lock.lock()
        progressOverride = progress.map { min(max($0.isFinite ? $0 : 0, 0), 1) }
        lock.unlock()
    }

    /// 生效的固定进度；nil 表示应走真实资源键。
    public var effectiveProgressOverride: Double? {
        lock.lock()
        defer { lock.unlock() }
        return progressOverride
    }

    /// 恢复生产配置。
    public func reset() {
        lock.lock()
        downloaderOverride = nil
        timeoutOverride = nil
        progressOverride = nil
        lock.unlock()
    }

    /// 按启动参数安装测试网关；无参数或参数非法时不作任何改动。
    ///
    /// 幂等：重复调用不会叠加状态。
    @discardableResult
    public func bootstrapFromLaunchArguments(
        _ arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        var didInstall = false

        // 两个参数彼此独立：只给进度参数而没给模式参数时，进度覆写仍须生效，
        // 因此不能把进度解析塞进模式参数的 guard 里提前返回。
        if let progress = Self.parseProgressOverride(arguments) {
            overrideProgress(progress)
            didInstall = true
        }

        guard let raw = arguments.first(where: { $0.hasPrefix(Self.launchArgumentKey) }) else {
            return didInstall
        }

        // 参数形如 `--key=value`：先按前缀命中键，再剥掉 `=` 与两侧空白取值。
        let rawValue = String(raw.dropFirst(Self.launchArgumentKey.count))
        let value = rawValue
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
            .trimmingCharacters(in: .whitespaces)

        switch value {
        case "success":
            override(StubUbiquitousItemDownloader(behavior: .succeeds(afterPolls: 2)))
            overrideTimeout(3)
        case "timeout":
            // 8s：UI 测试的可访问性轮询一次约 0.3-0.5s，且 App 启动恢复播放
            // 会自动触发一次下载，需要足够宽的观测窗口才能稳定捕获下载态。
            override(StubUbiquitousItemDownloader(behavior: .neverCompletes))
            overrideTimeout(8)
        case "offline":
            override(StubUbiquitousItemDownloader(behavior: .startFails(message: "network offline")))
            overrideTimeout(3)
        default:
            return didInstall
        }

        return true
    }

    /// 解析 `--cisum-ui-testing-download-progress=<0...1>`。
    ///
    /// 取不到合法数值时返回 nil（不覆写），避免坏参数让 UI 测试静默走到
    /// 真实进度上、断言失去意义。
    private static func parseProgressOverride(_ arguments: [String]) -> Double? {
        guard let raw = arguments.first(where: { $0.hasPrefix(progressLaunchArgumentKey) }) else {
            return nil
        }

        let rawValue = String(raw.dropFirst(progressLaunchArgumentKey.count))
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
            .trimmingCharacters(in: .whitespaces)

        guard let parsed = Double(rawValue), parsed.isFinite else { return nil }
        return min(max(parsed, 0), 1)
    }
}

// MARK: - Local content probe

extension URL {
    /// `hasLocalContent` 的实现体，供网关调用以避免与协议方法互相递归。
    ///
    /// 判据为「文件实际占用的磁盘空间」而非 iCloud 状态键：在「优化 Mac 存储」
    /// 下被驱逐的 dataless 文件，其 `totalFileAllocatedSize` 恒为 0，而
    /// `ubiquitousItemDownloadingStatus` 既不报 `.notDownloaded` 也不报
    /// `.current`，导致既不发起下载也无法判定完成。
    func magicKitHasLocalContent() -> Bool {
        guard isFileURL, isFileExist else { return false }

        guard let values = try? resourceValues(forKeys: [
            .isUbiquitousItemKey,
            .fileSizeKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
        ]) else {
            return true
        }

        // 只有 iCloud 项目才可能是「占位无内容」，其余一律视为本地可用
        guard values.isUbiquitousItem == true else { return true }

        // 空文件没有内容需要下载
        guard let fileSize = values.fileSize, fileSize > 0 else { return true }

        let allocatedSize = values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0
        return allocatedSize > 0
    }
}
