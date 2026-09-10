import Foundation
import ProviderBook
import CisumUIComponents
import OSLog
import SwiftUI

/// Thread-safe storage for cached covers and in-flight cover requests.
///
/// `BookCoverRepo` is called from multiple unstructured tasks, so all compound
/// cache operations (lookup/create/remove) must happen under the same lock.
final class BookCoverCache: @unchecked Sendable {
    private enum CachedCover {
        case image(Image)
        case missing

        var value: Image? {
            switch self {
            case let .image(image): image
            case .missing: nil
            }
        }
    }

    private struct InFlightRequest {
        let id: UUID
        let task: Task<Image?, Never>
    }

    private enum Lookup {
        case cached(Image?)
        case inFlight(Task<Image?, Never>)
    }

    private let lock = NSLock()
    private var results: [String: CachedCover] = [:]
    private var inFlightRequests: [String: InFlightRequest] = [:]

    func value(
        for key: String,
        loader: @escaping @Sendable () async -> Image?
    ) async -> Image? {
        let lookup = lock.withLock { () -> Lookup in
            if let cached = results[key] {
                return .cached(cached.value)
            }

            if let request = inFlightRequests[key] {
                return .inFlight(request.task)
            }

            let requestID = UUID()
            let task = Task { [self] in
                let result = await loader()
                finish(result, for: key, requestID: requestID)
                return result
            }
            inFlightRequests[key] = InFlightRequest(id: requestID, task: task)
            return .inFlight(task)
        }

        switch lookup {
        case let .cached(image):
            return image
        case let .inFlight(task):
            return await task.value
        }
    }

    func clear() {
        let tasks = lock.withLock {
            results.removeAll()
            let tasks = inFlightRequests.values.map(\.task)
            inFlightRequests.removeAll()
            return tasks
        }
        tasks.forEach { $0.cancel() }
    }

    func clear(forKeyPrefix prefix: String) {
        let tasks = lock.withLock {
            results = results.filter { !$0.key.hasPrefix(prefix) }
            let matchingRequests = inFlightRequests.filter { $0.key.hasPrefix(prefix) }
            for key in matchingRequests.keys {
                inFlightRequests.removeValue(forKey: key)
            }
            return matchingRequests.values.map(\.task)
        }
        tasks.forEach { $0.cancel() }
    }

    private func finish(_ result: Image?, for key: String, requestID: UUID) {
        lock.withLock {
            // A cache clear may have removed this request while its loader was
            // finishing. In that case, do not restore the stale result.
            guard inFlightRequests[key]?.id == requestID else { return }
            results[key] = result.map(CachedCover.image) ?? .missing
            inFlightRequests.removeValue(forKey: key)
        }
    }
}

/// 专门负责书籍封面图获取的仓库类
public final class BookCoverRepo: ObservableObject, SuperLog, @unchecked Sendable {
    public nonisolated static let emoji = "🖼️"
    private let verbose = false
    private nonisolated static let supportedCoverExtensions: Set<String> = [
        "apng",
        "bmp",
        "gif",
        "heic",
        "heif",
        "jpeg",
        "jpg",
        "png",
        "tif",
        "tiff",
        "webp",
    ]
    private nonisolated static let preferredCoverNames = [
        "cover",
        "folder",
        "front",
        "poster",
        "thumbnail",
    ]

    // MARK: - In-flight Deduplication & Cache

    private nonisolated static let coverCache = BookCoverCache()

    /// Cache key: standardized URL path + thumbnail size
    private static func cacheKey(for url: URL, size: CGSize) -> String {
        "\(url.resolvingSymlinksInPath().standardizedFileURL.path)_\(Int(size.width))x\(Int(size.height))"
    }

    // MARK: - Public Methods

    /// 获取书籍封面图
    /// - Parameters:
    ///   - url: 书籍URL
    ///   - thumbnailSize: 缩略图尺寸
    /// - Returns: 封面图，如果未找到则返回nil
    func getCover(for url: URL, thumbnailSize: CGSize) async -> Image? {
        let key = Self.cacheKey(for: url, size: thumbnailSize)
        return await Self.coverCache.value(for: key) { [verbose] in
            do {
                let result = try await Self.findCoverRecursively(in: url, thumbnailSize: thumbnailSize, verbose: verbose)
                return result
            } catch {
                os_log(.error, "\(Self.t)Failed to find cover for \(url.lastPathComponent): \(error.localizedDescription)")
                return nil
            }
        }
    }

    /// Returns the first matching cover file as raw data so a View plugin can
    /// perform platform-specific image decoding without depending on this
    /// repository type.
    public func getCoverData(for url: URL) async -> Data? {
        await Task.detached(priority: .background) {
            guard let coverURL = Self.findCoverURL(in: url) else { return nil }
            return try? Data(contentsOf: coverURL)
        }.value
    }

    /// Clears the cover cache. Call when books are refreshed or deleted.
    public static func clearCache() {
        coverCache.clear()
    }

    /// Clears cache for a specific book URL.
    static func clearCache(for url: URL) {
        let prefix = url.resolvingSymlinksInPath().standardizedFileURL.path + "_"
        coverCache.clear(forKeyPrefix: prefix)
    }

    // MARK: - Private Methods

    /// 递归查找封面图
    /// - Parameters:
    ///   - url: 目录URL
    ///   - thumbnailSize: 缩略图尺寸
    ///   - verbose: 是否输出详细日志
    /// - Returns: 封面图，如果未找到则返回nil
    private static func findCoverRecursively(in url: URL, thumbnailSize: CGSize, verbose: Bool) async throws -> Image? {
        // 确保在后台线程执行文件系统操作
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached(priority: .background) {
                do {
                    if verbose {
                        os_log("\(Self.t)findCoverRecursively \(url.title)")
                    }
                    let candidates = coverCandidates(in: url)

                    // 首先检查当前层级的文件
                    for child in candidates.files {
                        // 跳过未下载的 iCloud 文件
                        if child.checkIsICloud(verbose: false) && child.isNotDownloaded {
                            continue
                        }

                        if let cover = try await child.thumbnailImage(
                            size: thumbnailSize,
                            useDefaultIcon: false,
                            verbose: verbose,
                            reason: "BookCoverRepo"
                        ) {
                            continuation.resume(returning: cover)
                            return
                        }
                    }

                    // 如果当前层级没有找到封面，递归查找子文件夹
                    for child in candidates.folders {
                        if let cover = try await findCoverRecursively(in: child, thumbnailSize: thumbnailSize, verbose: verbose) {
                            continuation.resume(returning: cover)
                            return
                        }
                    }

                    continuation.resume(returning: nil)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func findCoverURL(in url: URL) -> URL? {
        let candidates = coverCandidates(in: url)
        for file in candidates.files {
            if file.checkIsICloud(verbose: false) && file.isNotDownloaded { continue }
            if let data = try? Data(contentsOf: file), !data.isEmpty { return file }
        }
        for folder in candidates.folders {
            if let coverURL = findCoverURL(in: folder) { return coverURL }
        }
        return nil
    }

    static func coverCandidates(in url: URL) -> (files: [URL], folders: [URL]) {
        guard url.isFolder else {
            return ([url], [])
        }

        let children = url.getChildren().sorted {
            $0.standardizedFileURL.path.localizedStandardCompare($1.standardizedFileURL.path) == .orderedAscending
        }
        return (
            files: children.filter { !$0.isFolder && isCoverImageCandidate($0) }
                .sorted(by: coverFileSort),
            folders: children.filter(\.isFolder)
        )
    }

    static func isCoverImageCandidate(_ url: URL) -> Bool {
        supportedCoverExtensions.contains(url.pathExtension.lowercased())
    }

    private static func coverFileSort(_ lhs: URL, _ rhs: URL) -> Bool {
        let lhsRank = coverNameRank(lhs)
        let rhsRank = coverNameRank(rhs)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }

        return lhs.standardizedFileURL.path.localizedStandardCompare(rhs.standardizedFileURL.path) == .orderedAscending
    }

    private static func coverNameRank(_ url: URL) -> Int {
        let name = url.deletingPathExtension().lastPathComponent.lowercased()
        return preferredCoverNames.firstIndex(of: name) ?? preferredCoverNames.count
    }
}
