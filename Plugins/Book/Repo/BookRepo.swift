import Combine
import Foundation
import MagicKit
import OSLog
import SwiftUI

@MainActor
class BookRepo: ObservableObject, SuperEvent, SuperLog {
    nonisolated static let emoji = "📖"
    static let verbose = false

    private let db: BookDB
    private var disk: URL
    private let verbose: Bool = false
    private var monitor: Cancellable?
    private nonisolated let coverRepo: BookCoverRepo

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

    init(disk: URL, db: BookDB) throws {
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

        return self.disk.onDirChange(
            verbose: self.verbose,
            caller: self.className,
            onChange: { items, isFirst, _ in
                if await Self.verbose {
                    os_log("\(self.t) Disk changed, with items \(items.count)")
                }
                if let lastTime = UserDefaults.standard.object(forKey: "BookLastUpdateTime") as? Date {
                    let now = Date()
                    guard now.timeIntervalSince(lastTime) >= debounceInterval else { return }
                }
                UserDefaults.standard.set(Date(), forKey: "BookLastUpdateTime")

                await self.sync(items, isFirst: isFirst)
            },
            onDeleted: { [weak self] _ in
                // Book 模块暂不处理删除后的额外逻辑
                guard let _ = self else { return }
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
    }

    func delete(_ book: BookModel, verbose: Bool) async {
//        try? self.disk.deleteFile(book.url)
//        self.emit(.audioDeleted)
    }

    func download(_ book: BookModel, verbose: Bool) async throws {
//        try await self.disk.download(book.url, reason: "BookDB.download", verbose: verbose)
    }

    func find(_ url: URL) async -> URL? {
        await self.db.hasBook(url) ? url : nil
    }

    /// 获取书籍封面图
    /// - Parameters:
    ///   - url: 书籍URL
    ///   - thumbnailSize: 缩略图尺寸
    /// - Returns: 封面图，如果未找到则返回nil
    func getCover(for url: URL, thumbnailSize: CGSize) async -> Image? {
        return await coverRepo.getCover(for: url, thumbnailSize: thumbnailSize)
    }
    
    /// 获取所有集合类型的书籍（文件夹）
    /// - Parameter reason: 调用原因，用于日志记录
    /// - Returns: 按顺序排序的书籍 DTO 列表
    func getAll(reason: String) async -> [BookDTO] {
        if verbose {
            os_log("\(self.t)📚 获取所有书籍集合 - 来源: \(reason)")
        }
        
        do {
            // 获取所有书籍的数据传输对象，只保留集合类型（文件夹）
            let allBooks = try await db.allBookDTOs()
            let books = allBooks.filter { $0.isCollection }.sorted { $0.order < $1.order }
            
            if Self.verbose {
                os_log("\(self.t)✅ 获取到 \(books.count) 本书籍")
            }
            
            return books
        } catch {
            os_log(.error, "\(self.t)❌ 获取书籍失败: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Setter

extension BookRepo {
}

// MARK: - Preview

#if os(macOS)
    #Preview("App - Large") {
        ContentView()
    .inRootView()
            .frame(width: 600, height: 1000)
    }

    #Preview("App - Small") {
        ContentView()
    .inRootView()
            .frame(width: 500, height: 800)
    }
#endif

#if os(iOS)
    #Preview("iPhone") {
        ContentView()
    .inRootView()
    }
#endif
