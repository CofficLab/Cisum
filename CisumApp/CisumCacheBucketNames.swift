import Foundation

/// App 级磁盘缓存桶的显示名。
///
/// 这些桶由 `MagicKit.AppDiskCache` 写入，不属于任何插件；
/// 缓存管理插件按插件名展示时会给它们注入这里的名字。
enum CisumCacheBucketNames {
    static func displayName(for bucketID: String) -> String? {
        if bucketID.hasSuffix(".cache.thumbnails") {
            return String(localized: "Thumbnail Cache")
        }
        if bucketID.hasSuffix(".cache.http") {
            return String(localized: "Network Cache")
        }
        if bucketID.hasSuffix(".cache.media") {
            return String(localized: "Media Cache")
        }
        return nil
    }
}