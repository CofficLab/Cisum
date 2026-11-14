import Foundation

/// URL 身份归一化策略。
///
/// 进度订阅表与查询结果两侧必须用**同一把尺子**比对，否则订阅上了却收不到事件。
/// 这里统一定义 `NSMetadataItem` 查询结果到订阅 URL 的匹配方式。
///
/// ## 为什么按路径而不是文件名
///
/// 若按 `lastPathComponent` 匹配，同名文件分布在不同目录时
/// （`~/Music/intro.mp3` 与 `~/Downloads/intro.mp3`），一个文件下载会把进度
/// **同时**推给另一个同名文件，产生串扰。
///
/// `NSMetadataQuery` 回传的 `NSMetadataItem` 带有 `NSMetadataItemPathKey`，
/// 因此直接按完整路径匹配即可消除歧义，无需任何降级猜测。
enum CloudDownloadIdentity {
    /// URL 的规范身份键。
    static func key(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    /// 从查询结果提取身份键。
    ///
    /// 优先取 `NSMetadataItemPathKey`（完整路径）。取不到时返回 `nil`——
    /// 此时**宁可漏推也不猜**：降级为按文件名匹配会引入串扰，而串扰会让用户
    /// 在一个文件上看到另一个文件的进度，属于错误的确定性行为。
    static func key(for item: NSMetadataItem) -> String? {
        guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else {
            return nil
        }
        return URL(fileURLWithPath: path).standardizedFileURL.path
    }
}

/// 进度归一化与单调合并策略。
///
/// ## 为什么必须单调
///
/// 进度有两个来源：系统推送的事件、以及调用方主动读取的快照。两源都可能读到 `0`
/// （例如 dataless 文件的资源键读数）。若让后到的 `0` 覆盖已发布的进度，进度环会
/// 从 50% 跳回 0% 并长时间停在那里。因此同一文件的进度**只升不降**。
enum CloudDownloadProgressPolicy {
    /// 把任意读数夹取到 `0...1`；非法值（NaN / 无穷 / 越界）一并收敛。
    static func normalized(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    /// 单调合并：任一源读到 `0` 不得打回已发布的进度。
    static func merged(current: Double, incoming: Double) -> Double {
        max(normalized(current), normalized(incoming))
    }
}