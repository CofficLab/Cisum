import Foundation
import KitEventObservation

/// `CloudDownloadProviding` 的生产实现。
///
/// 用一条 `NSMetadataQuery`（predicate 为 `IsDownloadingKey == YES`）监听系统里
/// **正在下载**的 iCloud 文件，把系统百分比转发为领域事件。
///
/// ## 与 MagicKit 的关系
///
/// 本实现**不复用** `MagicKit.GlobalDownloadMonitor`：它是包内 internal 类型，
/// 跨包不可见，且其内部按 `lastPathComponent` 匹配订阅者，会导致同名文件串进度。
/// 这里独立实现，只依赖 Foundation。
///
/// ## 线程模型
///
/// 查询在后台队列处理，事件在 `@MainActor` 上同步派发（`EventObserverStore` 是
/// MainActor 隔离的），因此消费方无需再做线程切换。
@MainActor
public final class CloudDownloadService: CloudDownloadProviding, @unchecked Sendable {
    private let eventObservers = EventObserverStore<CloudDownloadEvent>()
    private let monitor = UbiquitousDownloadQuery()

    public init() {
        monitor.start { [weak self] entry in
            Task { @MainActor in
                self?.handle(entry)
            }
        }
    }

    func handle(_ entry: UbiquitousDownloadQuery.Entry) {
        let progress = CloudDownloadProgressPolicy.normalized(entry.progress)
        eventObservers.send(.progressChanged(url: entry.url, progress: progress))
    }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (CloudDownloadEvent) -> Void
    ) -> any CloudDownloadProvidingObserverHandle {
        eventObservers.add(callback)
    }

    public func progress(for url: URL) -> Double {
        monitor.progressSnapshot(for: url)
    }
}

/// 底层 `NSMetadataQuery` 封装：一个进程一条查询，回调「正在下载」的文件及其百分比。
///
/// 不使用引用计数：predicate 本身就把结果集限制在「正在下载」的少量文件，
/// 无需订阅者声明兴趣集合，也就不存在「最后一个订阅者离开时该停查询」的问题。
/// 查询随 `CloudDownloadService` 生命周期存在。
final class UbiquitousDownloadQuery: @unchecked Sendable {
    struct Entry: Sendable {
        let url: URL
        let progress: Double
    }

    private let lock = NSLock()
    private var lastPublished: [String: Double] = [:]
    private var isRunning = false

    private let processingQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.providerclouddownload.query"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []

    /// - Parameter onChange: 在后台队列上收到更新时调用；调用方负责切主线程。
    func start(onChange: @escaping (Entry) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !isRunning else { return }
        isRunning = true

        let query = NSMetadataQuery()
        query.searchScopes = [
            NSMetadataQueryUbiquitousDocumentsScope,
            NSMetadataQueryUbiquitousDataScope,
        ]
        // 只关心「正在下载」的条目：结果集天然极小，且条目下完即自动离开结果集，
        // 由 removed 事件补发完成信号。
        query.predicate = NSPredicate(format: "%K == YES", NSMetadataUbiquitousItemIsDownloadingKey)
        query.operationQueue = processingQueue

        // 必须等首次收集完成后才启用更新，否则会漏掉变化。
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: query,
                queue: nil
            ) { _ in
                query.enableUpdates()
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidUpdate,
                object: query,
                queue: nil
            ) { [weak self] notification in
                self?.handle(notification, onChange: onChange)
            }
        )

        query.start()
        self.query = query
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard isRunning else { return }
        isRunning = false

        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        query?.stop()
        query = nil
        lastPublished.removeAll()
    }

    private func handle(_ notification: Notification, onChange: @escaping (Entry) -> Void) {
        guard let query = notification.object as? NSMetadataQuery else { return }
        // 更新期间禁用，避免遍历结果集时又被新更新打断。
        query.disableUpdates()
        defer { query.enableUpdates() }

        // 完成信号：条目因下载完毕而离开结果集。
        if let removed = notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem] {
            for item in removed {
                guard let key = CloudDownloadIdentity.key(for: item) else { continue }

                let alreadyFinished: Bool = lock.withLock {
                    (lastPublished[key] ?? 0) >= 1
                }
                guard !alreadyFinished else { continue }

                lock.withLock { lastPublished[key] = 1 }
                onChange(Entry(url: URL(fileURLWithPath: key), progress: 1))
            }
        }

        // 进行中的进度。
        for index in 0..<query.resultCount {
            guard
                let item = query.result(at: index) as? NSMetadataItem,
                let key = CloudDownloadIdentity.key(for: item),
                let percent = item.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? Double
            else { continue }

            // 单调合并：后到的低值（含 0）不得打回已发布的进度。
            // 对外播发的必须是合并后的值，与记录保持一致。
            let merged: Double? = lock.withLock {
                let next = CloudDownloadProgressPolicy.merged(
                    current: lastPublished[key] ?? 0,
                    incoming: CloudDownloadProgressPolicy.normalized(percent / 100)
                )
                guard next > (lastPublished[key] ?? 0) else { return nil }
                lastPublished[key] = next
                return next
            }
            guard let merged else { continue }

            onChange(Entry(url: URL(fileURLWithPath: key), progress: merged))
        }
    }

    /// 读取某 URL 的即时进度。
    ///
    /// 已下载 / 非 iCloud 文件返回 `1`；正在下载返回系统百分比的即时读数；
    /// 无法判定时返回 `0`。
    ///
    /// 注意：这是**兜底初始化**用的快照，不是事件流的替代品。生产环境对 dataless
    /// 占位文件常读到 `0`，真实进度以 `NSMetadataQuery` 推送的事件为准。
    func progressSnapshot(for url: URL) -> Double {
        let key = CloudDownloadIdentity.key(for: url)
        // 已推送过的进度优先：它是真实来源，快照不应把它打回 0。
        let tracked = lock.withLock { lastPublished[key] }
        if let tracked, tracked > 0 { return tracked }

        // 百分比的资源键没有 Swift 侧常量，按原始名声明。
        let percentKey = URLResourceKey(rawValue: "NSURLUbiquitousItemPercentDownloadedKey")
        guard let values = try? url.resourceValues(forKeys: [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
            .ubiquitousItemIsDownloadingKey,
            percentKey,
        ]) else { return 0 }

        // 非 iCloud 文件不参与下载，直接视为完成。
        guard values.isUbiquitousItem == true else {
            return FileManager.default.fileExists(atPath: url.path) ? 1 : 0
        }

        // `.current` 表示内容已在本地，与 kit 的快照口径保持一致。
        if values.ubiquitousItemDownloadingStatus == .current { return 1 }
        guard values.ubiquitousItemIsDownloading == true else { return 1 }

        if let percent = values.allValues[percentKey] as? Double, percent > 0 {
            return CloudDownloadProgressPolicy.normalized(percent / 100)
        }
        return 0
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}