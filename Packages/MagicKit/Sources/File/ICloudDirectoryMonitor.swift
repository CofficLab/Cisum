import Combine
import Foundation
import OSLog

final class ICloudDirectoryMonitorLifecycle: @unchecked Sendable {
    private let lock = NSLock()
    private var activeRunID: UUID?

    func beginRun() -> UUID {
        let runID = UUID()
        lock.lock()
        activeRunID = runID
        lock.unlock()
        return runID
    }

    func shouldStart(runID: UUID) -> Bool {
        lock.lock()
        let shouldStart = activeRunID == runID
        lock.unlock()
        return shouldStart
    }

    @discardableResult
    func cancel(runID: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard activeRunID == runID else {
            return false
        }

        activeRunID = nil
        return true
    }
}

/// 监听 iCloud 文件夹内容变化的专用类
/// - Note: 使用 NSMetadataQuery 进行 iCloud 文件同步状态监听
public final class ICloudDirectoryMonitor: SuperLog {
    public static let emoji = "☁️"

    private enum DirectoryScanError: Error {
        case incompleteSnapshot
    }
    
    // MARK: - Types

    public typealias onChangeCallback = @Sendable (_ files: [URL], _ isInitialFetch: Bool, _ error: Error?) -> Void
    public typealias onDeletedCallback = @Sendable (_ urls: [URL]) -> Void
    public typealias onProgressCallback = @Sendable (_ url: URL, _ progress: Double) -> Void

    /// 进度更新节流控制（防止过于频繁的进度更新）
    private actor ProgressThrottle {
        private var lastUpdateTime: [URL: Date] = [:]
        private var lastProgress: [URL: Double] = [:]
        private let minInterval: TimeInterval = 0.5

        func shouldUpdate(for url: URL, progress: Double) -> Bool {
            let now = Date()
            let lastTime = lastUpdateTime[url] ?? .distantPast
            let previousProgress = lastProgress[url] ?? 0.0

            let isFirstUpdate = lastProgress[url] == nil
            let isComplete = progress >= 1.0
            let timeElapsed = now.timeIntervalSince(lastTime) >= minInterval
            let significantChange = abs(progress - previousProgress) >= 0.05

            if isFirstUpdate || isComplete || timeElapsed || significantChange {
                lastUpdateTime[url] = now
                lastProgress[url] = progress
                return true
            }

            return false
        }

        func reset(for url: URL) {
            lastUpdateTime.removeValue(forKey: url)
            lastProgress.removeValue(forKey: url)
        }
    }

    // MARK: - Properties

    private let directoryURL: URL
    private let verbose: Bool
    private let caller: String
    private let onChange: onChangeCallback
    private let onDeleted: onDeletedCallback
    private let onProgress: onProgressCallback

    private let query = NSMetadataQuery()
    private var cancellables = Set<AnyCancellable>()
    private let progressThrottle = ProgressThrottle()
    private let lifecycle = ICloudDirectoryMonitorLifecycle()
    private let normalizedPath: String
    private let initialScanQueue = DispatchQueue(
        label: "com.cisum.icloud-directory-monitor.initial-scan",
        qos: .utility
    )
    private var didDeliverInitialScan = false

    // MARK: - Initialization

    /// 初始化 iCloud 目录监听器
    /// - Parameters:
    ///   - directoryURL: 要监听的目录 URL
    ///   - verbose: 是否打印详细日志
    ///   - caller: 调用者名称
    ///   - onProgress: 进度回调
    ///   - onDeleted: 删除回调
    ///   - onChange: 变化回调
    public init(
        directoryURL: URL,
        verbose: Bool,
        caller: String,
        onProgress: @escaping onProgressCallback,
        onDeleted: @escaping onDeletedCallback,
        onChange: @escaping onChangeCallback
    ) {
        self.directoryURL = directoryURL
        self.verbose = verbose
        self.caller = caller
        self.onChange = onChange
        self.onDeleted = onDeleted
        self.onProgress = onProgress

        // 确保路径以 "/" 结尾，避免前缀匹配到相似名称的目录
        self.normalizedPath = directoryURL.path.hasSuffix("/")
            ? directoryURL.path
            : directoryURL.path + "/"
    }

    // MARK: - Public Methods

    /// 启动监听
    /// - Returns: 取消令牌
    @discardableResult
    public func start() -> AnyCancellable {
        let runID = lifecycle.beginRun()

        // 1. 先配置查询参数
        configureQuery()

        // 2. 再设置通知处理器（必须在 startQuery 之前）
        setupNotificationHandlers()

        // 3. 最后启动查询（延迟一点，确保通知处理器已注册）
        let verbose = self.verbose
        let caller = self.caller
        let t = self.t
        let monitor = self
        Task { @MainActor in
            if verbose {
                os_log("\(t)⏳ (\(caller)) 准备启动查询...")
            }

            // 额外延迟，确保通知订阅生效
            try? await Task.sleep(for: .milliseconds(100))

            guard monitor.lifecycle.shouldStart(runID: runID) else {
                if verbose {
                    os_log("\(t)⏭️ (\(caller)) 查询启动已取消")
                }
                return
            }

            if verbose {
                os_log("\(t)🚀 (\(caller)) 正在启动查询...")
            }
            monitor.startQuery()
        }

        // Do not make the first library load depend on NSMetadataQuery. On
        // macOS, an iCloud document can be visible as a local placeholder
        // while metadata synchronization is paused or failing. FileManager
        // can still enumerate those URLs without downloading their contents.
        deliverInitialScan()

        // 关键修复：闭包需要捕获 self 的强引用（不使用 weak）
        // 这样返回的 AnyCancellable 会持有 ICloudDirectoryMonitor 实例，防止被释放
        // 不会造成循环引用，因为 cancellables 只存储通知订阅，不持有 self
        return AnyCancellable { [self, runID] in
            self.cancel(runID: runID)
        }
    }

    // MARK: - Private Methods - Query Setup

    private func configureQuery() {
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]

        if verbose {
            os_log("\(self.t)🔍 (\(self.caller)) 设置查询路径：\(self.normalizedPath)")
        }

        // 构建谓词：匹配指定目录下的文件，排除目录本身和系统文件
        let predicates = [
            NSPredicate(format: "%K BEGINSWITH %@", NSMetadataItemPathKey, self.normalizedPath),
            NSPredicate(format: "%K.length > %d", NSMetadataItemPathKey, self.normalizedPath.count),
            NSPredicate(format: "NOT %K ENDSWITH %@", NSMetadataItemFSNameKey, ".DS_Store"),
        ]

        query.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        query.valueListAttributes = [
            NSMetadataItemURLKey,
            NSMetadataUbiquitousItemPercentDownloadedKey,
            NSMetadataUbiquitousItemIsDownloadingKey,
        ]
    }

    private func setupNotificationHandlers() {
        if verbose {
            os_log("\(self.t)📡 (\(self.caller)) 设置通知处理器...")
        }

        // 监听查询更新
        NotificationCenter.default.publisher(for: .NSMetadataQueryDidUpdate)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if self.verbose {
                    os_log("\(self.t)📨 (\(self.caller)) 收到查询更新通知")
                }
                self.handleQueryUpdate(notification)
            }
            .store(in: &cancellables)

        // 监听初始查询完成
        NotificationCenter.default.publisher(for: .NSMetadataQueryDidFinishGathering)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if self.verbose {
                    os_log("\(self.t)📨 (\(self.caller)) 收到查询完成通知")
                }
                self.handleQueryFinished(notification)
            }
            .store(in: &cancellables)

        if verbose {
            os_log("\(self.t)✅ [\(self.caller)] 通知处理器已注册")
        }
    }

    private func startQuery() {
        let verbose = self.verbose
        let caller = self.caller
        let t = self.t
        DispatchQueue.main.async {
            if verbose {
                os_log("\(t)🎯 (\(caller)) 调用 query.start()")
                os_log("\(t)🔧 (\(caller)) 查询状态：started=\(self.query.isStarted), gathering=\(self.query.isGathering)")
            }
            self.query.start()

            if verbose {
                os_log("\(t)✅ (\(caller)) query.start() 已返回")
            }
        }
    }

    // MARK: - Private Methods - Event Handlers

    /// 已知文件的身份集合，用于区分「成员变化」与「内容物化变化」。
    ///
    /// 线程安全性：`NSMetadataQueryDidUpdate` 在 `processingQueue` / 主队列上送达，
    /// 而 `deliverInitialScan` 在 `initialScanQueue` 上首发快照，因此用锁保护。
    private let knownIdentities = IdentityLedger()

    /// `NSMetadataQuery` 的 `changedItems` 混合了两种本质不同的语义：
    ///
    /// 1. **成员变化**——文件进入 / 离开目录 / 被重命名。库的内容确实变了，
    ///    调用方必须重扫。
    /// 2. **物化进度变化**——`PercentDownloaded`、`IsDownloading` 随每次 iCloud
    ///    百分比推送而刷新。文件一直都在，既没出现也没消失，只是内容正在落盘。
    ///
    /// 两者都落在同一个 `changedItems` 里，而调用方（音频库同步）只有一种理解。
    /// 不分流的话，一个 69 MB 文件在下载期间每推进 1% 就会触发一次全量库重扫：
    /// 既无必要，又把「目录内容变了」这个真正的信号淹没在噪音里。
    ///
    /// 判据只有一条：**这个身份我们此前没见过**。见过的，说明它早已在库里，
    /// 此次变化只能是物化进度。
    private func partitionMembershipChanges(_ items: [NSMetadataItem]) -> [NSMetadataItem] {
        let pairs = items.compactMap { item in
            Self.identity(of: item, normalizedPath: normalizedPath).map { (item, $0) }
        }
        guard !pairs.isEmpty else { return [] }

        let fresh = Set(knownIdentities.insertNew(pairs.map(\.1)))
        return pairs.compactMap { fresh.contains($0.1) ? $0.0 : nil }
    }

    /// 条目的身份键：完整路径（重命名会改变它，故能同时覆盖新增与重命名）。
    private static func identity(of item: NSMetadataItem, normalizedPath: String) -> String? {
        let fsName = item.value(forAttribute: NSMetadataItemFSNameKey) as? String
        guard let fsName, !fsName.isEmpty, !fsName.hasSuffix(".DS_Store") else {
            return nil
        }

        guard let itemPath = item.value(forAttribute: NSMetadataItemPathKey) as? String,
              itemPath.hasPrefix(normalizedPath),
              itemPath.count > normalizedPath.count else {
            return nil
        }

        return itemPath
    }

    /// 已知身份集合的线程安全包装。
    ///
    /// 批量接口 `insertNew(_:)` 而非逐个 `insertIfNew(_:)`：后者会让同一批
    /// `changedItems` 里彼此不同的路径互相影响判定语义，也让调用方难以断言
    /// 「本批里究竟哪些是新的」。批量一次判定，结果确定且可测。
    final class IdentityLedger {
        private let lock = NSLock()
        private var identities: Set<String> = []

        /// 判定 `candidates` 中此前未见过的那些，并把它们记入基线。
        ///
        /// - Returns: 本批中确属新成员的子集（保持 `candidates` 的顺序与去重）。
        @discardableResult
        func insertNew(_ candidates: [String]) -> [String] {
            lock.lock()
            defer { lock.unlock() }

            var fresh: [String] = []
            var addedInThisBatch: Set<String> = []
            for candidate in candidates {
                guard !addedInThisBatch.contains(candidate) else { continue }
                if identities.insert(candidate).inserted {
                    addedInThisBatch.insert(candidate)
                    fresh.append(candidate)
                }
            }
            return fresh
        }

        /// 用一次完整快照重置基线，避免启动期的条目被误判为「新增」。
        func reset(to identities: Set<String>) {
            lock.lock()
            defer { lock.unlock() }
            self.identities = identities
        }

        /// 当前基线中的身份数量；供测试与诊断使用。
        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return identities.count
        }
    }

    private func handleQueryUpdate(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery, query === self.query else {
            return
        }

        let rawChangedItems = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem]
        let rawDeletedItems = notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem]

        if verbose {
            os_log("\(self.t)🔔 (\(self.caller)) 查询更新")
            os_log("\(self.t)  • 变更数：\(rawChangedItems?.count ?? 0)")
            os_log("\(self.t)  • 删除数：\(rawDeletedItems?.count ?? 0)")
        }

        // 手动应用谓词过滤
        let changedItems = filterItems(rawChangedItems)
        let deletedItems = filterItems(rawDeletedItems)

        // 下载进度更新走独立通道：它不改变目录内容，不应惊动库同步。
        handleDownloadProgress(changedItems)

        // 只有真正的新成员才通知调用方重扫目录。
        processResults(
            isInitial: false,
            changedItems: partitionMembershipChanges(changedItems),
            deletedItems: deletedItems
        )
    }

    private func handleQueryFinished(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery, query === self.query else {
            return
        }

        if verbose {
            os_log("\(self.t)✅ (\(self.caller)) 初始查询完成")
            os_log("\(self.t)  • 项目数量: \(query.resultCount)")

            // 打印所有找到的文件路径
            for i in 0..<min(query.resultCount, 10) { // 最多打印 10 个
                if let item = query.result(at: i) as? NSMetadataItem,
                   let path = item.value(forAttribute: NSMetadataItemPathKey) as? String {
                    os_log("\(self.t)  • [\(i)] \(path)")
                }
            }

            if query.resultCount > 10 {
                os_log("\(self.t)  • ... 还有 \(query.resultCount - 10) 个项目")
            }
        }

        // The initial result from NSMetadataQuery is not authoritative: it
        // can be empty while iCloud metadata sync is unavailable. The direct
        // filesystem scan started by `start()` is the source of truth.
        deliverInitialScan()
    }

    /// Delivers the initial directory snapshot once, serialized so a fast
    /// metadata-query completion cannot race the direct scan started at boot.
    private func deliverInitialScan() {
        initialScanQueue.async { [weak self] in
            guard let self else { return }
            guard !self.didDeliverInitialScan else { return }

            do {
                let urls = try Self.scanDirectoryContents(at: self.directoryURL)
                self.didDeliverInitialScan = true

                // 以首次快照作为「已知成员」基线。否则启动时就已经躺在目录里的
                // 每个文件，都会在 NSMetadataQuery 首次推更新时被误判为「新增」，
                // 引发一次多余的全量重扫——而且 iCloud 文件往往正处于下载中，
                // 这个误判会每来一次更新就复发一次。
                self.knownIdentities.reset(to: Set(urls.map(\.path)))

                self.onChange(urls, true, nil)
            } catch {
                // Keep the delivery flag unset so a later metadata-query
                // completion can retry after a transient filesystem error.
                self.onChange([], true, error)
            }
        }
    }

    /// Enumerates directory entries without reading file contents. This is
    /// intentionally compatible with iCloud placeholder files.
    static func scanDirectoryContents(at directoryURL: URL) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: directoryURL.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {
            throw CocoaError(.fileNoSuchFile)
        }

        var enumerationError: Error?
        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, error in
                enumerationError = error
                return false
            }
        ) else {
            throw URLError(.cannotOpenFile)
        }

        let urls = enumerator.compactMap { $0 as? URL }
        if let enumerationError {
            throw enumerationError
        }

        return try validateDirectoryScanResult(urls, at: directoryURL)
    }

    /// DirectoryEnumerator can stop early after a File Provider permission
    /// failure without throwing from iteration. Detect the common silent
    /// empty-result case so it is not mistaken for a genuinely empty library.
    static func validateDirectoryScanResult(_ urls: [URL], at directoryURL: URL) throws -> [URL] {
        guard urls.isEmpty else { return urls }

        let visibleEntries = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        guard visibleEntries.isEmpty else {
            throw DirectoryScanError.incompleteSnapshot
        }

        return urls
    }

    // MARK: - Private Methods - Processing

    private func filterItems(_ items: [NSMetadataItem]?) -> [NSMetadataItem] {
        items?.filter { item in
            guard let itemPath = item.value(forAttribute: NSMetadataItemPathKey) as? String else {
                return false
            }

            let matchesPrefix = itemPath.hasPrefix(normalizedPath)
            let isNotDirectory = itemPath.count > normalizedPath.count
            let isNotDSStore = !(item.value(forAttribute: NSMetadataItemFSNameKey) as? String ?? "").hasSuffix(".DS_Store")

            return matchesPrefix && isNotDirectory && isNotDSStore
        } ?? []
    }

    private func handleDownloadProgress(_ items: [NSMetadataItem]) {
        Task.detached { [weak self] in
            guard let self = self else { return }

            for item in items {
                guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                      let isDownloading = item.value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? Bool,
                      let percentDownloaded = item.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? Double
                else { continue }

                let progress = URLDownloadProgressPolicy.normalizedFraction(percentDownloaded: percentDownloaded)

                if isDownloading || progress >= 1.0 {
                    guard await self.progressThrottle.shouldUpdate(for: url, progress: progress) else { continue }

                    await MainActor.run {
                        self.onProgress(url, progress)
                    }

                    if progress >= 1.0 {
                        await self.progressThrottle.reset(for: url)
                    }
                } else {
                    await self.progressThrottle.reset(for: url)
                }
            }
        }
    }

    private func processResults(
        isInitial: Bool = false,
        changedItems: [NSMetadataItem]? = nil,
        deletedItems: [NSMetadataItem]? = nil
    ) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            self.query.disableUpdates()
            defer { self.query.enableUpdates() }

            let urls = self.extractUrls(isInitial: isInitial, changedItems: changedItems)

            if let deletedItems = deletedItems, !deletedItems.isEmpty {
                self.handleDeletedItems(deletedItems)
            }

            // 只有在有实际变化时才通知
            if isInitial || !urls.isEmpty {
                self.onChange(urls, isInitial, nil)
            } else if self.verbose {
                os_log("\(self.t)⏭️ (\(self.caller)) 无变化，跳过回调")
            }
        }
    }

    private func extractUrls(isInitial: Bool, changedItems: [NSMetadataItem]?) -> [URL] {
        if isInitial {
            let allItems = query.results as? [NSMetadataItem] ?? []
            return allItems.compactMap { $0.value(forAttribute: NSMetadataItemURLKey) as? URL }
        } else {
            return changedItems?.compactMap { item in
                guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { return nil }
                if self.verbose {
                    os_log("\(self.t)🍋 [\(self.caller)] 变更文件：\(url.lastPathComponent)")
                }
                return url
            } ?? []
        }
    }

    private func handleDeletedItems(_ items: [NSMetadataItem]) {
        if verbose {
            os_log("\(self.t)🔍 (\(self.caller)) 处理已删除项目")
            os_log("\(self.t)  • 项目数量: \(items.count)")
        }

        let fileManager = FileManager.default
        var deletedUrls: [URL] = []

        for (index, item) in items.enumerated() {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else {
                if verbose {
                    os_log(.error, "\(self.t)⚠️ (\(self.caller)) 已删除项目 \(index)：无 URL")
                }
                continue
            }

            let exists = fileManager.fileExists(atPath: url.path)
            if exists {
                if verbose {
                    os_log(.error, "\(self.t)⚠️ (\(self.caller)) 文件仍然存在：\(url.lastPathComponent)")
                }
                continue
            }

            deletedUrls.append(url)
            if verbose {
                os_log("\(self.t)✅ (\(self.caller)) 确认删除：\(url.lastPathComponent)")
            }
        }

        if !deletedUrls.isEmpty {
            if verbose {
                os_log("\(self.t)🗑️ (\(self.caller)) 调用 onDeleted")
                os_log("\(self.t)  • 文件数量: \(deletedUrls.count)")
            }

            DispatchQueue.main.async {
                self.onDeleted(deletedUrls)
            }
        }
    }

    // MARK: - Cleanup

    private func cancel(runID: UUID) {
        guard lifecycle.cancel(runID: runID) else {
            return
        }

        if verbose {
            os_log("\(self.t)⏹️ (\(self.caller)) 停止 iCloud 监控器")
        }

        query.stop()
        cancellables.removeAll()
    }
}
