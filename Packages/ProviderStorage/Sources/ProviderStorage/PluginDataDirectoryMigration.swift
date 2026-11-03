import Foundation

/// 插件数据目录迁移工具。
///
/// 插件的数据目录名从「业务化命名」（`audio`、`books_db`、`FileLog` …）
/// 统一为插件 ID 后，旧目录里的数据必须搬到新目录，否则用户会看到
/// 数据「凭空消失」。
///
/// 迁移语义刻意保守：
///
/// - **只在旧目录存在且新目录不存在时迁移**。新目录已存在说明新布局
///   已经跑过（或用户已有数据），此时不动任何东西——宁可留下一个孤儿
///   旧目录，也不要覆盖用户的新数据。
/// - **失败不抛错**。迁移失败不阻塞启动：新目录会被正常创建，用户最多
///   看到旧数据没有自动搬过来，而不是 App 起不来。
public enum PluginDataDirectoryMigration {
    /// 把 `legacyDirectory` 迁移到 `currentDirectory`。
    ///
    /// - Parameters:
    ///   - legacyDirectory: 旧目录（不存在则直接返回）。
    ///   - currentDirectory: 新目录（已存在则跳过）。
    /// - Returns: 迁移是否实际执行。
    @discardableResult
    public static func migrate(
        from legacyDirectory: URL,
        to currentDirectory: URL
    ) -> Bool {
        let fm = FileManager.default

        // 新目录已存在 → 跳过，避免覆盖用户的新数据。
        guard !fm.fileExists(atPath: currentDirectory.path) else { return false }

        var legacyIsDirectory: ObjCBool = false
        guard fm.fileExists(atPath: legacyDirectory.path, isDirectory: &legacyIsDirectory),
              legacyIsDirectory.boolValue else {
            return false
        }

        do {
            try fm.moveItem(at: legacyDirectory, to: currentDirectory)
            return true
        } catch {
            // 迁移失败不阻塞启动：新目录会被正常创建。
            return false
        }
    }
}
