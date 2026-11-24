import Foundation

/// App 级磁盘缓存目录约定。
///
/// 与 LumiProviders `DefaultDiskCacheProvider` 的布局保持一致：
/// `~/Library/Caches/<bundleID>/DiskCache/<bucketID>/objects/`。
/// 缓存管理插件按桶目录扫描占用、支持整桶清理，因此应用自管的
/// 「删了也能重建」的缓存都应落到这里，而不是散落在 Caches 根目录。
public enum AppDiskCache {
    /// 获取某个缓存桶的 objects 目录；目录不存在时创建。
    ///
    /// `bucketID` 只允许 `[A-Za-z0-9._-]`，与 DiskCache 桶目录名规则一致。
    public static func objectsDirectory(bucketID: String) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = caches
            .appendingPathComponent(MagicApp.getBundleIdentifier(), isDirectory: true)
            .appendingPathComponent("DiskCache", isDirectory: true)
            .appendingPathComponent(bucketID, isDirectory: true)
            .appendingPathComponent("objects", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}