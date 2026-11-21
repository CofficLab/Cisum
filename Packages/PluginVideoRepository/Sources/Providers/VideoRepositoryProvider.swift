import AVFoundation
import Combine
import Foundation
import MagicKit
import ProviderVideo
import CisumProviderStorage
import OSLog

/// `VideoRepositoryProviding` 的具体实现。
///
/// 仓库位置由存储层决定：`StorageProviding.storageRoot` 是全 App 共用的
/// 存储根（用户在首启引导里选 iCloud 或本地），视频库在其下建自己的子
/// 目录 `videos`——与音乐的 `audios`、有声书的 `audios_book` 同一套逻辑。
/// 存储位置变化时，本 Provider 重新解析仓库并重新扫描。
@MainActor
public final class VideoRepositoryProvider: VideoRepositoryProviding {
    nonisolated public static let logger = Logger(subsystem: "com.coffic.cisum", category: "plugin.video-repository")

    @Published public private(set) var state: VideoRepositoryState = .idle
    @Published public private(set) var repositoryURL: URL?
    @Published public private(set) var items: [VideoItem] = []

    private let storage: any StorageProviding
    private let metadataStore: VideoMetadataStore
    private let fileManager: FileManager
    private var observers: [VideoRepositoryObserver] = []
    private var storageObserver: (any StorageProvidingObserverHandle)?
    private var directoryMonitor: AnyCancellable?
    private var scanTask: Task<Void, Never>?

    /// - Parameters:
    ///   - storage: 存储能力，提供全 App 共用的存储根目录。
    ///   - pluginDataDirectory: 插件数据目录，用于存放元数据。
    ///   - fileManager: 文件管理器。
    public init(
        storage: any StorageProviding,
        pluginDataDirectory: URL,
        fileManager: FileManager = .default
    ) {
        self.storage = storage
        self.metadataStore = VideoMetadataStore(directory: pluginDataDirectory)
        self.fileManager = fileManager
        storageObserver = storage.addObserver { [weak self] _ in
            self?.reloadRepository()
        }
    }

    public var isAvailable: Bool {
        if case .ready = state { return true }
        return false
    }

    public var storageLocationTitle: String {
        storage.currentStorageLocation?.title ?? ""
    }

    // MARK: - Repository location

    /// 重新解析仓库目录并扫描。
    ///
    /// 存储位置切换（本地 ↔ iCloud）后由存储层事件触发。
    public func reloadRepository() {
        directoryMonitor?.cancel()
        directoryMonitor = nil

        guard let root = storage.storageRoot else {
            repositoryURL = nil
            state = .idle
            notify(.repositoryChanged(nil))
            return
        }

        let directory = root.appendingPathComponent(
            VideoPluginInfo.effectiveRepositoryDirName,
            isDirectory: true
        )
        do {
            try directory.ensureDirectory()
        } catch {
            state = .unavailable("Cannot create the video repository: \(error.localizedDescription)")
            notify(.repositoryChanged(nil))
            return
        }

        repositoryURL = directory
        state = .locating
        notify(.repositoryChanged(directory))
        startDirectoryMonitor(directory)
        startScan()
    }

    // MARK: - Scanning

    public func refresh() {
        startScan()
    }

    private func startScan() {
        guard let repositoryURL else { return }
        scanTask?.cancel()
        state = .scanning(repositoryURL)
        notify(.repositoryChanged(repositoryURL))

        scanTask = Task { [weak self] in
            guard let self else { return }
            let scanned = await Self.scanOffMain(repositoryURL, fileManager: self.fileManager)
            guard !Task.isCancelled else { return }
            await self.applyScan(scanned)
        }
    }

    /// 监听仓库目录变化：用户往仓库里放了新视频时自动刷新列表。
    private func startDirectoryMonitor(_ directory: URL) {
        directoryMonitor = directory.onDirChange(
            verbose: false,
            caller: "VideoRepositoryProvider"
        ) { [weak self] _, _, _ in
            await MainActor.run {
                self?.startScan()
            }
        }
    }

    private func applyScan(_ scanned: [ScannedVideo]) async {
        var current: [VideoItem] = []
        current.reserveCapacity(scanned.count)

        for video in scanned {
            let metadata = metadataStore.metadata(for: video.relativePath)
            let availability: VideoAvailability = video.isCloudPlaceholder ? .cloudNotDownloaded : .available
            current.append(
                VideoItem(
                    url: video.url,
                    relativePath: video.relativePath,
                    title: video.url.deletingPathExtension().lastPathComponent,
                    size: video.size,
                    modifiedAt: video.modifiedAt,
                    duration: metadata.progress.duration > 0 ? metadata.progress.duration : nil,
                    tags: metadata.tags,
                    rating: metadata.rating.flatMap(VideoRating.init),
                    progress: metadata.progress,
                    isFavorite: metadata.isFavorite,
                    availability: availability
                )
            )
        }

        items = current
        let root = repositoryURL ?? URL(fileURLWithPath: "/")
        state = .ready(root, scanned.count)
        notify(.itemsChanged(current))
        notify(.scanCompleted(root, scanned.count))

        await loadDurations(for: current)
    }

    /// 在后台读取媒体时长，读到后回填列表。
    private func loadDurations(for current: [VideoItem]) async {
        let pending = current.filter { $0.duration == nil || $0.duration == 0 }
        guard !pending.isEmpty else { return }

        let loaded = await withTaskGroup(of: (URL, TimeInterval?).self) { group in
            for item in pending {
                group.addTask {
                    let asset = AVURLAsset(url: item.url)
                    let duration = try? await asset.load(.duration)
                    return (item.url, duration.map { $0.seconds })
                }
            }
            var results: [(URL, TimeInterval?)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        let durations = Dictionary(uniqueKeysWithValues: loaded.compactMap { key, value in
            value.map { (key, $0) }
        })
        guard !durations.isEmpty else { return }

        var updated = items
        for index in updated.indices {
            if let duration = durations[updated[index].url] {
                updated[index] = VideoItem(
                    url: updated[index].url,
                    relativePath: updated[index].relativePath,
                    title: updated[index].title,
                    size: updated[index].size,
                    modifiedAt: updated[index].modifiedAt,
                    duration: duration,
                    tags: updated[index].tags,
                    rating: updated[index].rating,
                    progress: updated[index].progress,
                    isFavorite: updated[index].isFavorite,
                    availability: updated[index].availability
                )
                metadataStore.mutate(for: updated[index].relativePath) { metadata in
                    if metadata.progress.duration <= 0 {
                        metadata.progress.duration = duration
                    }
                }
            }
        }
        items = updated
        notify(.itemsChanged(updated))
    }

    /// 目录枚举在后台线程执行，避免阻塞主线程。
    private nonisolated static func scanOffMain(
        _ directory: URL,
        fileManager: FileManager
    ) async -> [ScannedVideo] {
        await Task.detached(priority: .userInitiated) {
            VideoRepositoryScanner.scan(directory: directory, fileManager: fileManager)
        }.value
    }

    public func updateAvailability(_ availability: VideoAvailability, for url: URL) {
        guard let index = items.firstIndex(where: { $0.url == url }) else { return }
        items[index] = VideoItem(
            url: items[index].url,
            relativePath: items[index].relativePath,
            title: items[index].title,
            size: items[index].size,
            modifiedAt: items[index].modifiedAt,
            duration: items[index].duration,
            tags: items[index].tags,
            rating: items[index].rating,
            progress: items[index].progress,
            isFavorite: items[index].isFavorite,
            availability: availability
        )
        notify(.itemsChanged(items))
    }

    // MARK: - Metadata

    public func setTags(_ tags: [String], for url: URL) {
        guard let item = items.first(where: { $0.url == url }) else { return }
        metadataStore.mutate(for: item.relativePath) { $0.tags = tags }
        refreshItem(for: url)
    }

    public func setRating(_ rating: Int?, for url: URL) {
        guard let item = items.first(where: { $0.url == url }) else { return }
        metadataStore.mutate(for: item.relativePath) { metadata in
            metadata.rating = rating.flatMap { VideoRating($0)?.value }
        }
        refreshItem(for: url)
    }

    public func setFavorite(_ isFavorite: Bool, for url: URL) {
        guard let item = items.first(where: { $0.url == url }) else { return }
        metadataStore.mutate(for: item.relativePath) { $0.isFavorite = isFavorite }
        refreshItem(for: url)
    }

    public func updateProgress(_ progress: VideoPlaybackProgress, for url: URL) {
        guard let item = items.first(where: { $0.url == url }) else { return }
        metadataStore.mutate(for: item.relativePath) { $0.progress = progress }
        refreshItem(for: url)
    }

    private func refreshItem(for url: URL) {
        guard let index = items.firstIndex(where: { $0.url == url }) else { return }
        let item = items[index]
        let metadata = metadataStore.metadata(for: item.relativePath)
        items[index] = VideoItem(
            url: item.url,
            relativePath: item.relativePath,
            title: item.title,
            size: item.size,
            modifiedAt: item.modifiedAt,
            duration: item.duration,
            tags: metadata.tags,
            rating: metadata.rating.flatMap(VideoRating.init),
            progress: metadata.progress,
            isFavorite: metadata.isFavorite,
            availability: item.availability
        )
        notify(.itemsChanged(items))
    }

    // MARK: - File management

    public func rename(_ url: URL, to newName: String) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw VideoRepositoryError.invalidName
        }
        guard !trimmed.contains("/"), !trimmed.contains(":") else {
            throw VideoRepositoryError.invalidName
        }

        let directory = url.deletingLastPathComponent()
        let fileExtension = url.pathExtension
        let targetName = fileExtension.isEmpty ? trimmed : "\(trimmed).\(fileExtension)"
        let target = directory.appendingPathComponent(targetName, isDirectory: false)

        guard target != url else { return }
        guard !fileManager.fileExists(atPath: target.path) else {
            throw VideoRepositoryError.alreadyExists
        }

        try fileManager.moveItem(at: url, to: target)

        if let root = repositoryURL {
            let oldPath = VideoRepositoryScanner.relativePath(
                of: url,
                under: root.standardizedFileURL.path
            )
            let newPath = VideoRepositoryScanner.relativePath(
                of: target,
                under: root.standardizedFileURL.path
            )
            metadataStore.migrate(from: oldPath, to: newPath)
        }

        startScan()
    }

    public func delete(_ url: URL) throws {
        do {
            try fileManager.trashItem(at: url, resultingItemURL: nil)
        } catch {
            // 废纸篓不可用时退回直接删除。
            try fileManager.removeItem(at: url)
        }

        if let root = repositoryURL {
            let path = VideoRepositoryScanner.relativePath(
                of: url,
                under: root.standardizedFileURL.path
            )
            metadataStore.remove(for: path)
        }

        startScan()
    }

    // MARK: - Import & download

    /// 把外部视频文件复制进仓库。
    ///
    /// 同名文件自动追加 `-1`、`-2` 序号，不覆盖已有文件；导入完成后触发
    /// 一次重新扫描。
    public func importVideos(from urls: [URL]) throws {
        guard let root = repositoryURL else { throw VideoRepositoryError.noRepository }

        for source in urls {
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }

            guard fileManager.fileExists(atPath: source.path) else {
                throw VideoRepositoryError.notFound
            }

            let target = uniqueDestination(for: source, in: root)
            try fileManager.copyItem(at: source, to: target)
        }

        startScan()
    }

    /// 在仓库内为导入文件挑一个不冲突的目标路径。
    private func uniqueDestination(for source: URL, in root: URL) -> URL {
        let base = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension
        var candidate = root.appendingPathComponent(source.lastPathComponent, isDirectory: false)
        var index = 1
        while fileManager.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(base)-\(index)" : "\(base)-\(index).\(ext)"
            candidate = root.appendingPathComponent(name, isDirectory: false)
            index += 1
        }
        return candidate
    }

    /// 触发 iCloud 下载，并把条目状态切到「下载中」。
    public func requestDownload(for url: URL) {
        guard (try? FileManager.default.startDownloadingUbiquitousItem(at: url)) != nil else { return }
        updateAvailability(.cloudDownloading, for: url)
    }

    // MARK: - Observers

    @discardableResult
    public func addObserver(
        _ callback: @escaping (VideoRepositoryEvent) -> Void
    ) -> any VideoRepositoryObserverHandle {
        let observer = VideoRepositoryObserver(callback: callback)
        observers.append(observer)
        return observer
    }

    private func notify(_ event: VideoRepositoryEvent) {
        observers.removeAll { $0.isCancelled }
        for observer in observers {
            observer.invoke(event)
        }
    }

    /// 退出时释放资源。
    public func shutdown() {
        scanTask?.cancel()
        scanTask = nil
        directoryMonitor?.cancel()
        directoryMonitor = nil
        storageObserver?.cancel()
        storageObserver = nil
        observers.removeAll()
    }
}

/// 仓库操作可能抛出的错误。
public enum VideoRepositoryError: LocalizedError {
    case invalidName
    case alreadyExists
    case notFound
    case noRepository

    public var errorDescription: String? {
        switch self {
        case .invalidName: "The name is invalid"
        case .alreadyExists: "A file with the same name already exists"
        case .notFound: "The video file no longer exists"
        case .noRepository: "The video repository is not available"
        }
    }
}

/// 仓库事件的观察句柄。
final class VideoRepositoryObserver: VideoRepositoryObserverHandle {
    private let callback: (VideoRepositoryEvent) -> Void
    private var cancelled = false

    init(callback: @escaping (VideoRepositoryEvent) -> Void) {
        self.callback = callback
    }

    var isCancelled: Bool { cancelled }

    func cancel() { cancelled = true }

    func invoke(_ event: VideoRepositoryEvent) {
        guard !cancelled else { return }
        callback(event)
    }
}
