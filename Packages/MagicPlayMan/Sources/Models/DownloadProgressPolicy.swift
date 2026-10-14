import Foundation

/// 下载进度的多源合并策略。
///
/// 顶部播放器（Hero）的下载进度有两个来源：
/// ① **轮询源**：URL 资源键快照（`getDownloadProgressSnapshot`，percent key +
///    allocatedSize 兜底）——生产环境对 dataless 占位文件长期读到 0；
/// ② **事件源**：`GlobalDownloadMonitor` 从 `NSMetadataItem` 的 percent key
///    推送的进度——**仓库列表进度环使用的就是这条链路**，真实有效。
///
/// 两源必须单调合并：同一文件的下载进度只升不降，任一源读到 0 都不得
/// 把另一源已发布的进度覆盖回 0%（否则 Hero 会一直显示「0% 正在下载」，
/// 与列表的进度环不一致）。
enum MagicPlayManDownloadProgressPolicy {
    static func merged(current: Double, incoming: Double) -> Double {
        max(normalized(current), normalized(incoming))
    }

    private static func normalized(_ value: Double) -> Double {
        MagicPlayManPlaybackTimePolicy.normalizedUnitProgress(value)
    }
}
