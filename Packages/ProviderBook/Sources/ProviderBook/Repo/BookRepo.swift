import Combine
import Foundation
import ProviderBook
import CisumUIComponents
import OSLog
import SwiftUI

@MainActor
public class BookRepo: ObservableObject, SuperEvent, SuperLog {
    public nonisolated static let emoji = "📖"
    public static let verbose = false

    private let db: BookDB
    private var disk: URL
    private let verbose: Bool = false
    private var monitor: Cancellable?
    private nonisolated let coverRepo: BookCoverRepo
    private var initialSyncCompleted = false
    private var initialSyncWaiters: [CheckedContinuation<Void, Never>] = []

    // MARK: - State

    enum SyncStatusBook: Equatable {
        case idle
        case syncing(items: [URL])
        case synced
        case updated
        case error(String)

        var description: String {
            switch self {
            case .idle: return "idle"
            case .syncing: return "syncing"
            case .synced: return "synced"
            case .updated: return "updated"
            case .error: return "error"
            }
        }
    }

    public init(disk: URL, db: BookDB) throws {
        self.db = db
        self.disk = disk
        self.coverRepo = BookCoverRepo()
        self.monitor = try self.makeMonitor()
    }

    func makeMonitor() throws -> Cancellable {
        if verbose {
            os_log("\(self.t)📸 Make monitor for: \(self.disk.shortPath())")
        }

        if self.disk.isNotDirExist {
            os_log(.error, "\(self.t)Error: \(self.disk.absoluteString) not exist")
            throw BookPluginError.DiskNotFound
        }

        let debounceInterval = 2.5

        let monitoredDisk = self.disk

        return monitoredDisk.onDirChange(
            verbose: self.verbose,
            caller: self.className,
            onChange: { items, isFirst, error in
                if await Self.verbose {
                    os_log("\(self.t) Disk changed, with items \(items.count)")
                }
                if let error {
                    os_log(.error, "\(self.t) Directory scan failed: \(error.localizedDescription)")
                    await self.completeInitialSyncIfNeeded()
                    return
                }
                if !isFirst, let lastTime = UserDefaults.standard.object(forKey: "BookLastUpdateTime") as? Date {
                    let now = Date()
                    guard now.timeIntervalSince(lastTime) >= debounceInterval else { return }
                }
                UserDefaults.standard.set(Date(), forKey: "BookLastUpdateTime")

                let shouldFullSync = isFirst || !monitoredDisk.checkIsICloud(verbose: false)
                await self.sync(items, isFirst: shouldFullSync)
            },
            onDeleted: { [weak self] urls in
                Task {
                    await self?.delete(urls)
                }
            },
            onProgress: { _, _ in
                // Book 模块暂不处理下载进度
            }
        )
    }
}

// MARK: - Action

extension BookRepo {
    private func sync(_ items: [URL], isFirst: Bool) async {
        await self.db.sync(items, isFirst: isFirst)
        if isFirst {
            completeInitialSyncIfNeeded()
        }
    }

    /// Wait until the directory monitor has finished its first full sync.
    ///
    /// The monitor starts its initial scan asynchronously during init. Without
    /// waiting here, a first database read can race that scan and incorrectly
    /// render the empty-repository state.
    private func waitForInitialSync() async {
        guard !initialSyncCompleted else { return }

        await withCheckedContinuation { continuation in
            if initialSyncCompleted {
                continuation.resume()
            } else {
                initialSyncWaiters.append(continuation)
            }
        }
    }

    private func completeInitialSyncIfNeeded() {
        guard !initialSyncCompleted else { return }

        initialSyncCompleted = true

        let waiters = initialSyncWaiters
        initialSyncWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    public func syncImportedItems(_ items: [URL]) async throws {
        guard !items.isEmpty else { return }

        try await self.db.syncImportedItems(items)
    }

    private func delete(_ urls: [URL]) async {
        await self.db.delete(urls: urls)
    }

    func delete(_ book: BookModel, verbose: Bool) async {
//        try? self.disk.deleteFile(book.url)
//        self.emit(.audioDeleted)
    }

    func download(_ book: BookModel, verbose: Bool) async throws {
//        try await self.disk.download(book.url, reason: "BookDB.download", verbose: verbose)
    }

    public func find(_ url: URL) async -> URL? {
        await self.db.hasBook(url) ? url : nil
    }

    public func playbackState(for bookURL: URL) async -> BookPlaybackStateDTO? {
        try? await db.playbackState(for: bookURL)
    }

    public func savePlaybackState(
        for bookURL: URL,
        currentURL: URL?,
        time: TimeInterval?
    ) async throws {
        try await db.savePlaybackState(
            for: bookURL,
            currentURL: currentURL,
            time: time
        )
    }

    /// 获取书籍封面图
    /// - Parameters:
    ///   - url: 书籍URL
    ///   - thumbnailSize: 缩略图尺寸
    /// - Returns: 封面图，如果未找到则返回nil
    public nonisolated func getCover(for url: URL, thumbnailSize: CGSize) async -> Image? {
        return await coverRepo.getCover(for: url, thumbnailSize: thumbnailSize)
    }

    public nonisolated func getCoverData(for url: URL) async -> Data? {
        await coverRepo.getCoverData(for: url)
    }
    
    /// 获取所有集合类型的书籍（文件夹）
    /// - Parameter reason: 调用原因，用于日志记录
    /// - Returns: 按顺序排序的书籍 DTO 列表
    public func getAll(reason: String) async -> [BookDTO] {
        os_log("\(self.t)📚 getAll 开始 - 来源: \(reason)")

        let syncStart = DispatchTime.now()
        await waitForInitialSync()
        let syncNanos = DispatchTime.now().uptimeNanoseconds - syncStart.uptimeNanoseconds
        let syncSeconds = Double(syncNanos) / 1_000_000_000
        if syncSeconds > 0.01 {
            os_log("\(self.t)⏳ 初始同步等待完成 (\(String(format: "%.2f", syncSeconds))s)")
        }
        
        do {
            // 获取所有书籍的数据传输对象，只保留顶层书籍，包含文件夹书和单文件书。
            let fetchStart = DispatchTime.now()
            let allBooks = try await db.allBookDTOs()
            let fetchNanos = DispatchTime.now().uptimeNanoseconds - fetchStart.uptimeNanoseconds
            let fetchSeconds = Double(fetchNanos) / 1_000_000_000
            os_log("\(self.t)🗃️ DB 查询完成: \(allBooks.count) 条原始记录 (\(String(format: "%.3f", fetchSeconds))s)")

            let libraryRoot = disk
            // DTO filtering performs symlink/path resolution for every item.
            // Keep that filesystem work off the main actor; only the final
            // value crosses back to the UI-facing repository.
            let filterStart = DispatchTime.now()
            let books = await Task.detached(priority: .utility) {
                allBooks
                    .filter { Self.isDisplayableLibraryItem($0, libraryRoot: libraryRoot) }
                    .sorted { $0.order < $1.order }
            }.value
            let filterNanos = DispatchTime.now().uptimeNanoseconds - filterStart.uptimeNanoseconds
            let filterSeconds = Double(filterNanos) / 1_000_000_000

            os_log("\(self.t)✅ getAll 完成: \(books.count) 本书籍可展示 (过滤 \(allBooks.count - books.count) 条, \(String(format: "%.3f", filterSeconds))s)")
            
            return books
        } catch {
            os_log(.error, "\(self.t)❌ 获取书籍失败: \(error.localizedDescription)")
            return []
        }
    }

    public nonisolated static func isDisplayableLibraryItem(
        url: URL,
        isCollection: Bool,
        childCount: Int,
        libraryRoot: URL
    ) -> Bool {
        guard BookPathContainment.hasSameResolvedParent(url, as: libraryRoot) else {
            return false
        }

        if isCollection {
            return childCount > 0
        }

        return BookPluginInfo.supportedExtensions.contains(url.pathExtension.lowercased())
    }

    nonisolated static func isDisplayableLibraryItem(_ book: BookDTO, libraryRoot: URL) -> Bool {
        isDisplayableLibraryItem(
            url: book.url,
            isCollection: book.isCollection,
            childCount: book.childCount,
            libraryRoot: libraryRoot
        )
    }
}

// MARK: - Setter

extension BookRepo {
}
