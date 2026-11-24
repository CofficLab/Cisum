import Foundation

/// 旧版本把缩略图 / HTTP / 播放器缓存直接写在 Caches 根目录，
/// 不在 DiskCache 桶内，缓存管理插件统计与清理不到。
/// 这些内容都可由本地文件重建或重新下载，启动时顺手删掉即可。
enum CisumLegacyDiskCache {
    private static let legacyDirectoryNames = [
        "ThumbnailCache",
        "HttpClientCache",
        "MagicPlayMan",
    ]

    static func removeLegacyDirectories() {
        guard let caches = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else { return }

        DispatchQueue.global(qos: .utility).async {
            for name in legacyDirectoryNames {
                try? FileManager.default.removeItem(
                    at: caches.appendingPathComponent(name, isDirectory: true)
                )
            }
        }
    }
}