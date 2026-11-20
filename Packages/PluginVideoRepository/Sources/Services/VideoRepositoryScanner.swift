import Foundation
import ProviderVideo

/// 扫描到的一个视频文件。
public struct ScannedVideo: Equatable, Sendable {
    public let url: URL
    public let relativePath: String
    public let size: Int64
    public let modifiedAt: Date?
    /// 文件位于 iCloud 且尚未下载到本地。
    public let isCloudPlaceholder: Bool

    public init(
        url: URL,
        relativePath: String,
        size: Int64,
        modifiedAt: Date?,
        isCloudPlaceholder: Bool
    ) {
        self.url = url
        self.relativePath = relativePath
        self.size = size
        self.modifiedAt = modifiedAt
        self.isCloudPlaceholder = isCloudPlaceholder
    }
}

/// 仓库扫描器：递归枚举目录，收集受支持的视频文件。
public enum VideoRepositoryScanner {
    /// 扫描目录下的所有视频文件。
    ///
    /// - Parameters:
    ///   - directory: 仓库根目录。
    ///   - fileManager: 文件管理器。
    /// - Returns: 按相对路径排序的视频列表。
    public static func scan(
        directory: URL,
        fileManager: FileManager = .default
    ) -> [ScannedVideo] {
        var keys: [URLResourceKey] = [
            .isRegularFileKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .isHiddenKey,
            .isUbiquitousItemKey,
        ]
        keys.append(.ubiquitousItemDownloadingStatusKey)

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        let rootPath = directory.standardizedFileURL.path
        var results: [ScannedVideo] = []

        for case let url as URL in enumerator {
            guard VideoFileSupport.isSupported(url) else { continue }

            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile == true else { continue }

            let relativePath = Self.relativePath(of: url, under: rootPath)
            let isCloudPlaceholder = Self.isCloudPlaceholder(values)

            results.append(
                ScannedVideo(
                    url: url,
                    relativePath: relativePath,
                    size: Int64(values?.fileSize ?? 0),
                    modifiedAt: values?.contentModificationDate,
                    isCloudPlaceholder: isCloudPlaceholder
                )
            )
        }

        return results.sorted {
            $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending
        }
    }

    /// 判断资源是否位于 iCloud 且尚未下载到本地。
    ///
    /// 各平台统一用下载状态（`URLUbiquitousItemDownloadingStatus`）判断。
    private static func isCloudPlaceholder(_ values: URLResourceValues?) -> Bool {
        guard let values, values.isUbiquitousItem == true else { return false }
        return values.ubiquitousItemDownloadingStatus == .notDownloaded
    }

    /// 计算文件相对仓库根目录的路径。
    public static func relativePath(of url: URL, under rootPath: String) -> String {
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath) else { return url.lastPathComponent }
        var relative = String(path.dropFirst(rootPath.count))
        while relative.hasPrefix("/") { relative.removeFirst() }
        return relative.isEmpty ? url.lastPathComponent : relative
    }
}
