import Foundation

/// 插件数据目录迁移工具。
///
/// 插件的数据目录名从「业务化命名」（`audio`、`books_db`、`FileLog` …）
/// 一路演进到「反向 DNS」（`com.coffic.cisum.plugin.audio-db-data`）。
/// 目录名变了，旧目录里的数据就必须搬到新目录，否则用户会看到数据「凭空消失」。
///
/// ## 迁移语义
///
/// - **新目录为空或不存在时才迁移**。新目录里已经有内容说明新布局已经
///   跑过（或用户已有数据），此时不动任何东西——宁可留下一个孤儿旧目录，
///   也不要覆盖用户的新数据。
/// - **失败不抛错**。迁移失败不阻塞启动：新目录会被正常创建，用户最多
///   看到旧数据没有自动搬过来，而不是 App 起不来。
/// - **按历史顺序尝试**。目录名改过不止一次，磁盘上可能留下几个名字；
///   按「从旧到新」的顺序依次尝试，搬到第一个还存在的那一个。
///
/// ## 目录存在性的陷阱
///
/// 迁移必须在目标目录被创建**之前**执行。`pluginDataDirectory(for:)` 会创建
/// 目录，若先用它拿到目标路径，「新目录是否已存在」的判断就永远为真，
/// 迁移永远不执行——旧目录原地留下，新目录变成空壳，App 读到的是空数据。
/// 因此这里统一用「只解析路径」的方式计算目标路径，插件不要自己拼。
public enum PluginDataDirectoryMigration {
    /// 把历史目录迁移到当前插件目录。
    ///
    /// - Parameters:
    ///   - legacyDirectoryNames: 历史目录名，按时间**从旧到新**排列。
    ///   - pluginID: 当前插件 id（新目录名 = 插件 id）。
    ///   - dataRootDirectory: 数据根目录（插件目录直接位于其下）。
    /// - Returns: 迁移是否实际执行。
    @discardableResult
    public static func migrate(
        legacyDirectoryNames: [String],
        pluginID: String,
        dataRootDirectory: URL
    ) -> Bool {
        let currentDirectory = dataRootDirectory
            .appendingPathComponent(pluginID, isDirectory: true)

        for legacyName in legacyDirectoryNames {
            let legacyDirectory = dataRootDirectory
                .appendingPathComponent(legacyName, isDirectory: true)
            if migrate(from: legacyDirectory, to: currentDirectory) {
                return true
            }
        }
        return false
    }

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
