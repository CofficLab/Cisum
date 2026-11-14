
import Foundation
import Combine
import SwiftUI
import OSLog

/// 全局下载监控器 (内部单例)
/// 负责维护唯一的 NSMetadataQuery 并分发事件
final class GlobalDownloadMonitor: SuperLog {
    public nonisolated static let emoji = "👂"
    public nonisolated static let verbose = false

    static let shared = GlobalDownloadMonitor()
    
    // 订阅者信息: [URL: [UUID: (lastUpdateTime, interval, callback)]]
    private typealias SubscriberInfo = (lastUpdateTime: TimeInterval, interval: TimeInterval, callback: (Double) -> Void)
    private var subscribers: [URL: [UUID: SubscriberInfo]] = [:]
    private let lock = NSLock()
    
    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    
    // 后台处理队列
    private let processingQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.magickit.url.downloading.global"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    /// 添加订阅者
    func addSubscriber(
        url: URL,
        updateInterval: TimeInterval,
        onProgress: @escaping (Double) -> Void
    ) -> UUID {
        lock.lock()
        defer { lock.unlock() }
        
        let uuid = UUID()
        let info: SubscriberInfo = (lastUpdateTime: 0, interval: updateInterval, callback: onProgress)
        
        if subscribers[url] == nil {
            subscribers[url] = [:]
        }
        subscribers[url]?[uuid] = info
        
        startQueryIfNeeded()
        
        // 立即检查一次当前状态
        let currentProgress = url.getDownloadProgressSnapshot()
        if currentProgress > 0 {
            // 注意：onProgress 应该在合适线程调用，但这里是直接回调
            // 考虑到这是 addSubcriber，通常在主线程调用，直接回调也是安全的
            // 且这是快照，不需要通过 queue
            onProgress(currentProgress)
        }
        
        return uuid
    }
    
    /// 移除订阅者
    func removeSubscriber(url: URL, uuid: UUID) {
        lock.lock()
        defer { lock.unlock() }
        
        if var urlSubs = subscribers[url] {
            urlSubs.removeValue(forKey: uuid)
            if urlSubs.isEmpty {
                subscribers.removeValue(forKey: url)
            } else {
                subscribers[url] = urlSubs
            }
        }
        
        stopQueryIfNoSubscribers()
    }
    
    // MARK: - Query Management
    
    private func startQueryIfNeeded() {
        guard query == nil else { return }
        
        let q = NSMetadataQuery()
        q.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope, NSMetadataQueryUbiquitousDataScope]
        
        // 改进 Predicate: 使用 Boolean 类型的 IsDownloading 键，比字符串状态更可靠
        q.predicate = NSPredicate(format: "%K == YES", NSMetadataUbiquitousItemIsDownloadingKey)
        q.operationQueue = processingQueue
        
        // 监听 Gather 开始
        let startObs = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidStartGathering,
            object: q,
            queue: nil
        ) { _ in
            if Self.verbose { os_log("\(Self.t)🏁 Query 开始收集数据 (DidStartGathering)") }
        }
        observers.append(startObs)
        
        // 监听 Gather 完成
        let finishObs = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: q,
            queue: nil
        ) { _ in
            if Self.verbose { os_log("\(Self.t)🏁 Query 完成收集数据 (DidFinishGathering)") }
            // 必须在完成收集后启用更新，以确保后续变更能收到通知
            q.enableUpdates()
        }
        observers.append(finishObs)
        
        // 监听更新
        let updateObs = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: q,
            queue: nil // on processingQueue
        ) { [weak self] notification in
            self?.handleQueryUpdate(notification)
        }
        observers.append(updateObs)
        
        q.start()
        query = q

        if Self.verbose {
            os_log("\(Self.t)🚀 启动全局查询 IsDownloading=YES")
        }
    }
    
    private func stopQueryIfNoSubscribers() {
        guard subscribers.isEmpty else { return }
        
        if let q = query {
            q.stop()
            query = nil
            if Self.verbose {
                os_log("\(Self.t)⏹️ 停止全局查询")
            }
        }
        
        // 移除所有观察者
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
    
    private func handleQueryUpdate(_ notification: Notification) {
        // 如果开启 verbose，打印一条简洁日志表明收到了通知
        if Self.verbose {
            os_log("\(Self.t)🔔 收到 Query 更新通知")
        }
        
        guard let q = notification.object as? NSMetadataQuery else { return }
        q.disableUpdates()
        
        let currentTime = Date().timeIntervalSince1970
        let userInfo = notification.userInfo
        
        // 1. 处理移除的项目 (可能已经下载完成)
        if let removedItems = userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem] {
            if Self.verbose && !removedItems.isEmpty {
                 os_log("\(Self.t)🗑️ Query 移除了 \(removedItems.count) 个项目")
            }
            
            for item in removedItems {
                guard let filename = item.value(forAttribute: NSMetadataItemFSNameKey) as? String else { continue }
                
                // 查找订阅者
                lock.lock()
                let matchedSubs = subscribers.filter { $0.key.lastPathComponent == filename }
                lock.unlock()
                
                for (url, urlSubs) in matchedSubs {
                    // 检查文件是否确实已下载完成
                    // 因为 Removed 也可能是因为文件被删除，或者其他状态变更
                     if url.isDownloaded {
                        if Self.verbose {
                            os_log("\(Self.t)✅ 文件下载完成 (Query移除): \(filename)")
                        }
                        // 发送完成信号 (1.0)
                        for (_, info) in urlSubs {
                            info.callback(1.0)
                        }
                    }
                }
            }
        }
        
        // 2. 处理更新的项目 (正在下载中)
        let resultCount = q.resultCount
        if Self.verbose && resultCount > 0 {
             os_log("\(Self.t)📥 Query 包含 \(resultCount) 个正在下载的项目")
        }
        
        for i in 0..<resultCount {
            guard let item = q.result(at: i) as? NSMetadataItem,
                  let filename = item.value(forAttribute: NSMetadataItemFSNameKey) as? String,
                  let percent = item.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? Double
            else { continue }
            
            let progress = percent / 100.0
            
            // 查找匹配的订阅者
            lock.lock()
            let matchedSubs = subscribers.filter { $0.key.lastPathComponent == filename }
            lock.unlock()
            
            for (url, var urlSubs) in matchedSubs {
                var updated = false
                
                for (uuid, var info) in urlSubs {
                    if currentTime - info.lastUpdateTime >= info.interval {
                        info.lastUpdateTime = currentTime
                        urlSubs[uuid] = info // Update struct in dict
                        updated = true
                        
                        if Self.verbose {
                             // 只有真实通知出去时才打印，避免刷屏
                             os_log("\(Self.t)🔄 分发进度 \(Int(progress * 100))%: \(filename)")
                        }
                        info.callback(min(progress, 1.0))
                    }
                }
                
                if updated {
                    lock.lock()
                    subscribers[url] = urlSubs
                    lock.unlock()
                }
            }
        }
        
        q.enableUpdates()
    }
}
