import Foundation
import ProviderVideo

/// 单个视频的用户元数据。
public struct VideoMetadata: Codable, Equatable, Sendable {
    /// 用户标签。
    public var tags: [String]
    /// 星级评分（1...5）。
    public var rating: Int?
    /// 是否收藏。
    public var isFavorite: Bool
    /// 播放进度。
    public var progress: VideoPlaybackProgress

    public init(
        tags: [String] = [],
        rating: Int? = nil,
        isFavorite: Bool = false,
        progress: VideoPlaybackProgress = .empty
    ) {
        self.tags = tags
        self.rating = rating
        self.isFavorite = isFavorite
        self.progress = progress
    }

    /// 空元数据。
    public static let empty = VideoMetadata()
}

/// 视频元数据的磁盘存储。
///
/// 元数据以「仓库相对路径」为键写在插件数据目录下的 JSON 里：路径变了
/// （重命名）就迁移键，文件被删就丢弃键。
///
/// 之所以不用数据库：视频库是单机资产，标签/评分/进度都是小体量数据，
/// JSON 便于直接查看与迁移，也避免在 App 层引入额外的容器装配。
public final class VideoMetadataStore: @unchecked Sendable {
    private static let fileName = "video-metadata.json"
    private static let schemaVersion = 1

    private struct Payload: Codable {
        var version: Int
        var entries: [String: VideoMetadata]
    }

    private let fileURL: URL
    private let lock = NSLock()
    private var entries: [String: VideoMetadata]

    /// - Parameter directory: 插件数据目录。
    public init(directory: URL) {
        fileURL = directory.appendingPathComponent(Self.fileName, isDirectory: false)
        entries = Self.readPayload(from: fileURL).entries
    }

    /// 读取某个视频的元数据。
    public func metadata(for relativePath: String) -> VideoMetadata {
        lock.lock()
        defer { lock.unlock() }
        return entries[relativePath] ?? .empty
    }

    /// 写入某个视频的元数据。
    public func update(_ metadata: VideoMetadata, for relativePath: String) {
        lock.lock()
        entries[relativePath] = metadata
        lock.unlock()
        persist()
    }

    /// 修改某个视频的元数据。
    public func mutate(for relativePath: String, _ transform: (inout VideoMetadata) -> Void) {
        lock.lock()
        var metadata = entries[relativePath] ?? .empty
        transform(&metadata)
        entries[relativePath] = metadata
        lock.unlock()
        persist()
    }

    /// 重命名时迁移键。
    public func migrate(from oldPath: String, to newPath: String) {
        lock.lock()
        if let metadata = entries.removeValue(forKey: oldPath) {
            entries[newPath] = metadata
        }
        lock.unlock()
        persist()
    }

    /// 删除某个视频的元数据。
    public func remove(for relativePath: String) {
        lock.lock()
        entries.removeValue(forKey: relativePath)
        lock.unlock()
        persist()
    }

    /// 当前所有条目（仅用于测试与诊断）。
    public var allEntries: [String: VideoMetadata] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    // MARK: - Persistence

    private func persist() {
        lock.lock()
        let payload = Payload(version: Self.schemaVersion, entries: entries)
        lock.unlock()

        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func readPayload(from url: URL) -> Payload {
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return Payload(version: schemaVersion, entries: [:])
        }
        return payload
    }
}
