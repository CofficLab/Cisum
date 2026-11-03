import Foundation

/// 插件数据目录迁移工具。
///
/// 插件的数据目录名从「业务化命名」（`audio`、`books_db`、`FileLog` …）
/// 统一为插件 ID 后，旧目录里的数据必须搬到新目录，否则用户会看到
/// 数据「凭空消失」。
///
/// 迁移语义刻意保守：
///
/// - **新目录为空或不存在时才迁移**。新目录里已经有内容说明新布局已经
///   跑过（或用户已有数据），此时不动任何东西——宁可留下一个孤儿旧目录，
///   也不要覆盖用户的新数据。
/// - **失败不抛错**。迁移失败不阻塞启动：新目录会被正常创建，用户最多
///   看到旧数据没有自动搬过来，而不是 App 起不来。
///
/// ## 目录存在性的陷阱
///
/// 目标目录的解析必须走 `StorageProviding.pluginDataDirectoryPath(for:)`，
/// 而不是 `pluginDataDirectory(for:)`——后者会**创建目录**。若先创建再判断
/// 「新目录是否已存在」，这个判断永远为真，迁移就永远不会执行：旧目录原地
/// 留下，新目录变成空壳，App 读到的是空数据。
public enum PluginDataDirectoryMigration {
    /// 把 `legacyDirectory` 迁移到 `currentDirectory`。
    ///
    /// - Parameters:
    ///   - legacyDirectory: 旧目录（不存在则直接返回）。
    ///   - currentDirectory: 新目录（已有内容则跳过）。
    /// - Returns: 迁移是否实际执行。
    @discardableResult
    public static func migrate(
        from legacyDirectory: URL,
        to currentDirectory: URL
    ) -> Bool {
        let fm = FileManager.default

        var legacyIsDirectory: ObjCBool = false
        guard fm.fileExists(atPath: legacyDirectory.path, isDirectory: &legacyIsDirectory),
              legacyIsDirectory.boolValue else {
            return false
        }

        // 新目录已有内容 → 跳过，避免覆盖用户的新数据。
        guard !containsContent(currentDirectory) else { return false }

        do {
            // 目标目录可能已被创建成空壳（见上方说明），此时先移除再搬。
            if fm.fileExists(atPath: currentDirectory.path) {
                try fm.removeItem(at: currentDirectory)
            }
            try fm.moveItem(at: legacyDirectory, to: currentDirectory)
            return true
        } catch {
            // 迁移失败不阻塞启动：新目录会被正常创建。
            return false
        }
    }

    /// 目录是否已存在且包含内容。
    ///
    /// 「存在但为空」视为可迁移目标——这正是「目录被提前创建成空壳」的
    /// 情形，此时旧数据仍然应当搬过去。
    private static func containsContent(_ directory: URL) -> Bool {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        let contents = (try? fm.contentsOfDirectory(atPath: directory.path)) ?? []
        return !contents.isEmpty
    }
}
