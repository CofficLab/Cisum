import Foundation

/// 数据层同步的容量兜底策略。
///
/// ## 为什么需要兜底
///
/// 容量闸门（`AudioCapacityProviding`）拦的是**应用内的写入入口**：
/// 拖放、文件选择器。但仓库目录同时是用户可见的文件夹——应用本身就提供
/// 「打开仓库文件夹」入口，用户可以直接把文件拷进去。目录监控随后会把
/// 这些文件同步进索引。
///
/// 如果不兜底，用户就能通过「手动放文件」绕过上限，限制形同虚设。
///
/// ## 兜底原则：只挡新增，不动存量
///
/// 兜底**只阻止超出上限的新文件进入索引**，绝不删除或隐藏已有记录。理由：
///
/// - 存量文件是用户已经拥有的内容。删掉它们是数据损失，且不是「限额」的
///   语义——限额管的是「还能再加多少」，不是「你现在拥有多少」。
/// - 用户付费后应当立刻能听到全部已有文件。若兜底把超限文件从索引移除，
///   付费后还得等一次同步才回得来，体验上是「付了钱文件却不见了」。
///
/// 因此策略是：**按稳定顺序保留前 N 个，其余留在磁盘上但不进索引**。
/// 用户付费后额度放宽，下一次同步它们自然回到索引。
///
/// ## 稳定顺序
///
/// 保留哪 N 个必须**确定**：每次同步都保留同样的 N 个，否则文件会在
/// 索引里忽进忽出。这里按路径排序后取前 N 个，与 `AudioDB` 已有的稳定
/// 插入顺序（`sortedForStableInsertion`）一致。
enum AudioSyncCapacityGuard {
    /// 筛选出可以进入索引的文件。
    ///
    /// - Parameters:
    ///   - urls: 待同步的候选文件（已去重、已过滤不支持的格式）。
    ///   - existingCount: 已经在索引里的文件数量。
    ///   - fileLimit: 免费档上限；`nil` 表示不限（付费用户）。
    /// - Returns: 允许进入索引的文件。
    static func admittedURLs(
        urls: [URL],
        existingCount: Int,
        fileLimit: Int?
    ) -> [URL] {
        // 不限容量：全部放行。
        guard let fileLimit else { return urls }

        // 已有文件已用掉的额度。
        let remaining = max(0, fileLimit - max(0, existingCount))
        guard remaining < urls.count else { return urls }

        // 超出的部分不进索引（文件仍留在磁盘上，付费后会自动回到索引）。
        return Array(urls.prefix(remaining))
    }
}
